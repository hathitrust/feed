package HTFeed::PackageType::MPubDCU::METS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::XMLNamespaces qw(:namespaces :schemas);
use base qw(HTFeed::METS);
use POSIX qw(strftime);


# Override base class _add_dmdsecs to not try to add MARC


sub _add_dmdsecs {
    my $self   = shift;
    my $volume = $self->{volume};
    my $mets   = $self->{mets};

    my $dmdsec =
      new METS::MetadataSection( 'dmdSec',
        'id' => $self->_get_subsec_id("DMD") );
    $dmdsec->set_md_ref(
        mdtype       => 'MARC',
        loctype      => 'OTHER',
        otherloctype => 'Item ID stored as second call number in item record',
        xptr         => $volume->get_identifier()
    );
    $mets->add_dmd_sec($dmdsec);

}

sub _add_schemas {
    my $self = shift;
    my $mets = $self->{mets};

    # add PREMIS1 namespace but don't worry about validating it
    $mets->add_schema( "PREMIS", NS_PREMIS1);
    $mets->add_schema( "MARC",   NS_MARC,   SCHEMA_MARC );

}

sub _add_premis {
    my $self = shift;
    my $volume = $self->{volume};
    my $nspkg = $volume->get_nspkg();
    my $xpc = $volume->get_repository_mets_xpc();
    $self->{parser} = new XML::LibXML;
    return unless defined $xpc;

    # preservationLevel

    # keep track of count for each kind of event
    $self->{premis_xml} = "";
    $self->{event_type_counters} = {};
    $self->{old_events} = {};

    my $premis_obj_MD =
      new METS::MetadataSection( 'techMD', 'id' => 'premisobject1' );
    $premis_obj_MD->set_xml_node( $self->{parser}->parse_xml_chunk(<<"EOT"), mdtype => 'PREMIS' );

        <PREMIS:object xmlns:PREMIS="http://www.loc.gov/standards/premis">
               <PREMIS:preservationLevel>1</PREMIS:preservationLevel>
        </PREMIS:object>
EOT
    push( @{ $self->{amd_mdsecs} }, $premis_obj_MD );

    $self->{premis_node} = new XML::LibXML::DocumentFragment();

    # old PREMIS events
    foreach my $event ($xpc->findnodes('//premis1:event')) {
        my $PREMIS_id = $xpc->findvalue('.//premis1:eventIdentifierValue',$event);
        my $PREMIS_type = $xpc->findvalue('.//premis1:eventType',$event);
        my $PREMIS_date = $xpc->findvalue('.//premis1:eventDateTime',$event);

        $self->{old_events}{$PREMIS_type}{$PREMIS_date} = $event;

	# canonicalize to ensure namespaces handled correctly
	$self->{premis_node}->appendChild($event);
        my ($eventIdPrefix,$eventCount) = $PREMIS_id =~ /^(\D+)(\d+)$/;
        if(defined $eventCount) {
            if(not defined $self->{event_type_counters}{$eventIdPrefix}
                    or $self->{event_type_counters}{$eventIdPrefix} < $eventCount) {
                $self->{event_type_counters}{$eventIdPrefix} = $eventCount;
            }
        } else {
            $self->set_error("BadField",field => "premis1:eventIdentifierValue",actual=>$PREMIS_id);
        }
    }

    # new events

    my $capture_agent = $volume->get_nspkg()->get('capture_agent');

    my $capture_time = $self->_get_capture_time();
    my $checksum_time = $self->_get_checksum_time();

    $self->_add_premis_event(type => 'capture', time => $capture_time, agent => $capture_agent);
    $self->_add_premis_event(type => 'compression', time => $capture_time, agent => $capture_agent);

    # message digest calculation -> Google, convert date from source METS


    # only add fixity check event if there was a checksum file with the SIP
    if(-e $volume->get_staging_directory() . "/" . $volume->get_nspkg()->get('checksum_file')) {
        $self->_add_premis_event(type => 'fixity check', time => $self->_get_event_time('page_md5_fixity'), agent => 'UM',
                               outcome => <<"EOT");
                 <PREMIS:eventOutcomeInformation>
                        <PREMIS:eventOutcomeDetail>pass</PREMIS:eventOutcomeDetail>
                 </PREMIS:eventOutcomeInformation>
EOT
        $self->_add_premis_event(type => 'message digest calculation', time => $checksum_time, agent => $capture_agent);
    } else {
        $self->_add_premis_event(type => 'message digest calculation', time => $checksum_time, agent => 'UM');
    }

    $self->_add_premis_event(type => 'validation', time => $self->_get_event_time('package_validation'), agent => 'UM');

    # ingestion -> now
    # last chance to record, even though it's not done yet
    $volume->record_premis_event('ingestion');
    $self->_add_premis_event(type => 'ingestion', time => $self->_get_event_time('ingestion'), agent => 'UM');

    my $digiprovMD =
      new METS::MetadataSection( 'digiprovMD', 'id' => 'premisevent1' );
    $digiprovMD->set_xml_node($self->{premis_node}, mdtype => 'PREMIS' );
    push( @{ $self->{amd_mdsecs} }, $digiprovMD );

    return;
}

sub _add_premis_event {
    my $self = shift;
    my %params = @_;
    my $namespace = NS_PREMIS1;

    foreach my $param (qw(type agent time)) {
        if(not defined $params{$param} or $params{$param} eq '') {
            $self->set_error("MissingField",field=>"premis_$param",actual=>\%params);
        }
    }

    my $outcome = "";
    $outcome = "\n" . $params{outcome} if defined $params{outcome};

    # Haven't seen this event: get a new event ID and add it
    if(not defined ($self->{'old_events'}{$params{'type'}}{$params{'time'}})) {
    

        my $eventSeq = ++$self->{event_type_counters}{$params{type}};

        $self->{premis_node}->appendChild( $self->{parser}->parse_xml_chunk(<<EOT));
         <PREMIS:event xmlns:PREMIS="$namespace">
          <PREMIS:eventIdentifier>
           <PREMIS:eventIdentifierValue>$params{type}$eventSeq</PREMIS:eventIdentifierValue>
          </PREMIS:eventIdentifier>
          <PREMIS:eventType>$params{type}</PREMIS:eventType>
          <PREMIS:eventDateTime>$params{time}</PREMIS:eventDateTime>$outcome
          <PREMIS:linkingAgentIdentifier>
           <PREMIS:linkingAgentIdentifierType>AgentID</PREMIS:linkingAgentIdentifierType>
           <PREMIS:linkingAgentIdentifierValue>$params{agent}</PREMIS:linkingAgentIdentifierValue>
          </PREMIS:linkingAgentIdentifier>
         </PREMIS:event>
EOT
    }

}

# get just the event time from the recorded premis event, since that's all we need for
# PREMIS 1
sub _get_event_time {
    my $self = shift;
    my $event_id = shift;

    my ($eventid, $date, $outcome_node) = $self->{volume}->get_event_info($event_id);

    return $date;

}

# Override parent class: don't add source METS; add content filegroups in specific order
sub _add_filesecs {
    my $self = shift;

    $self->_add_zip_fg();
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    # then add the actual content files
    my $filegroups = $volume->get_file_groups();
    $self->{filegroups} = {};

    foreach my $filegroup_name (qw(image ocr pdf)) {
        my $filegroup = $filegroups->{$filegroup_name};
        my $mets_filegroup = new METS::FileGroup(
            id  => $self->_get_subsec_id("FG"),
            use => $filegroup->get_use()
        );
        $mets_filegroup->add_files( $filegroup->get_filenames(),
            prefix => $filegroup->get_prefix(),
            path => $volume->get_staging_directory() );

        $self->{filegroups}{$filegroup_name} = $mets_filegroup;
        $mets->add_filegroup($mets_filegroup);
    }

}

# return the DateTime header from the first page image as the capture date
sub _get_capture_time {
    my $self = shift;
    my $volume = $self->{volume};

    my $firstimage = $volume->get_staging_directory() . "/00000001.tif";
    if(! -e $firstimage) {
        $firstimage = $volume->get_staging_directory() . "/00000001.jp2";
    }
    if(! -e $firstimage) {
        $self->set_error("MissingFile",file=>"00000001.{jp2,tif}",detail=>"Can't find first page image");
    }
    # try to get the capture date for the first image
    my $exifTool = new Image::ExifTool;
    $exifTool->ExtractInfo($firstimage);
    my $capture_date = $exifTool->GetValue('DateTime','XMP-tiff');
    if(not defined $capture_date) {
        $capture_date = $exifTool->GetValue('ModifyDate','IFD0');
    }
    if(not defined $capture_date or !$capture_date) {
        $self->set_error("BadField",file => $firstimage,field=>"XMP-tiff:DateTime",detail=>"Couldn't get capture time with ExifTool");
        return;
    }  else {
        $capture_date =~ s/(\d{4}).(\d{2}).(\d{2}).(\d{2}).(\d{2}).(\d{2})(.*)/$1-$2-$3T$4:$5:$6$7/; # fix separator
        return $capture_date;
    }
}

# checksum calculation time: use timestamp from checksum.md5
sub _get_checksum_time { 
    my $self = shift;
    my $volume = $self->{volume};
    my $path = $volume->get_staging_directory();
    my $checksum_file = $volume->get_nspkg()->get('checksum_file');
	my $checksum_path = "$path/$checksum_file";

    if(-e $checksum_path) {
        my $checksum_secs = (stat($checksum_path))[9];

        return strftime("%Y-%m-%dT%H:%M:%S",localtime($checksum_secs));
    } else {
        return strftime("%Y-%m-%dT%H:%M:%S",localtime);
    }

}

1;
