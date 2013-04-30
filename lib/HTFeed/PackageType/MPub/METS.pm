package HTFeed::PackageType::MPub::METS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::XMLNamespaces qw(:namespaces :schemas);
use base qw(HTFeed::METS);
use POSIX qw(strftime);
use Image::ExifTool;

sub _add_source_mets_events {

    my $self = shift;
    my $volume = $self->{volume};

    # only do this if we aren't uplifting?
    
    if(!$self->is_uplift()) {
        my $capture_time = $self->_get_capture_time();
        my $checksum_time = $self->_get_checksum_time();
        # FIXME: use this capture agent instead of MiU... need to use controlled vocabulary (FUTURE)
        my $capture_agent = $volume->get_nspkg()->get('capture_agent');

        {
            my $eventcode = 'capture';
            my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
            $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_time);
            $eventconfig->{'executor'} = 'MiU';
            $eventconfig->{'executor_type'} = 'MARC21 Code';
            $eventconfig->{'date'} = $capture_time;
            my $event = $self->add_premis_event($eventconfig);
        }
        {
            my $eventcode = 'image_compression';
            my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
            $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_time);
            $eventconfig->{'executor'} = 'MiU';
            $eventconfig->{'executor_type'} = 'MARC21 Code';
            $eventconfig->{'date'} = $capture_time;
            my $event = $self->add_premis_event($eventconfig);
        }

        {
            my $eventcode = 'page_md5_create';
            my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
            $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$checksum_time);
            $eventconfig->{'executor'} = 'MiU';
            $eventconfig->{'executor_type'} = 'MARC21 Code';
            $eventconfig->{'date'} = $capture_time;
            my $event = $self->add_premis_event($eventconfig);
        }

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
	$exifTool->Options("ScanForXMP" => 1);
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

        return strftime("%Y-%m-%dT%H:%M:%SZ",gmtime($checksum_secs));
    } else {
        return strftime("%Y-%m-%dT%H:%M:%SZ",gmtime);
    }

}

sub _extract_old_premis {
    my $self = shift;
    my $volume = $self->{volume};
    my $nspkg = $volume->get_nspkg();
    my $xpc = $volume->get_repository_mets_xpc();
    return unless defined $xpc;

    my %premis1_event_map = (
        capture => [qw(capture)],
        # we know the Google source METS & image compression was done at the same time as page md5 creation
        'compression' => [qw(image_compression)],
        'message digest calculation' => [qw(page_md5_create)],
        'fixity check' => [qw(page_md5_fixity)],
        'ingestion' => [qw(ingestion zip_compression zip_md5_create)],
        'validation' => [qw(package_validation)],
        'dummy ocr creation' => [qw(dummy_ocr_creation)]
    );

    # FIXME: $volume->record_premis_event('mets_update');
    my $had_premis1 = 0;
    foreach my $event ($xpc->findnodes('//premis1:event | //premis11:event')) {
        $had_premis1 = 1;
        my $premis1_type = $xpc->findvalue('./premis1:eventType | ./premis11:eventType',$event);
        if(my $eventcodes = $premis1_event_map{$premis1_type}) {
            foreach my $eventcode (@$eventcodes) {
                my $eventconfig = $nspkg->get_event_configuration($eventcode);
                my $from_tz = undef;
                $eventconfig->{date} = $xpc->findvalue('./premis1:eventDateTime | ./premis11:eventDateTime',$event);
                # tool is not represented in PREMIS1; don't make up one
                delete $eventconfig->{'tools'};

                my @agents = $xpc->findnodes('./premis1:linkingAgentIdentifier | ./premis11:linkingAgentIdentifier',$event);
                if(@agents != 1) {
                    $self->set_error("BadField",field => "linkingAgentIdentifier",
                        detail => "Expected 1 linking agent, found " . scalar(@agents));
                }
                my $agent = $agents[0];
                my $agentid = $xpc->findvalue('./premis1:linkingAgentIdentifierValue | ./premis11:linkingAgentIdentifierValue',$agent);
                if($agentid eq 'Google, Inc.') {
                    $eventconfig->{'executor_type'} = 'MARC21 Code';
                    $eventconfig->{'executor'} = 'Ca-MvGOO';
                    $from_tz = 'America/Los_Angeles';
#                } elsif($agentid eq 'UM' 
#                        or $agentid =~ /University.*Michigan/i
#                        or $agentid =~ /^SPO$/i
#                        or $agentid =~ /Digital.Conversion/i
#                        or $agentid =~ /MPublishing/i
#                        or $agentid =~ /Trigonix/i
#                        or $agentid =~ /UM Press/i
#                        or $agentid =~ /UNKNOWN/i
#                ) {
                } else {
                    # assume MPub/DCU is always MiU
                    $eventconfig->{'executor_type'} = 'MARC21 Code';
                    $eventconfig->{'executor'} = 'MiU';
                    $from_tz = 'America/Detroit';
                }
#                } else {
#                    $self->set_error("BadField",field=>"linkingAgentIdentifierValue",
#                        actual => $agentid, 
#                        detail => "Unknown agent ID");
#                }

                # if date doesn't have a time zone and we know what time zone it should be
                if($eventconfig->{date} =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/ and defined $from_tz) {
                    $eventconfig->{date} = $self->convert_tz($eventconfig->{date},$from_tz);
                } 

                $eventconfig->{'eventid'} =  $volume->make_premis_uuid($eventconfig->{'type'},$eventconfig->{'date'});

                $self->{old_event_types}->{$eventconfig->{type}} = $event;
                $self->add_premis_event($eventconfig);
            }
        }
    }
    $volume->record_premis_event('premis_migration') if($had_premis1);

    # get any PREMIS2 events if they are there..
    return $self->SUPER::_extract_old_premis();
}


1;
