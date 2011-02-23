#!/usr/bin/perl

package HTFeed::METS;
use strict;
use warnings;
use METS;
use PREMIS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas);
use Carp;
use Log::Log4perl qw(get_logger);
use Time::localtime;
use Cwd qw(cwd abs_path);
use HTFeed::Config qw(get_config);
use Date::Manip;
use File::Basename qw(basename dirname);

use base qw(HTFeed::Stage);

my $logger = get_logger(__PACKAGE__);

# return estimated space needed on ramdisk
sub ram_disk_size{
    return 1048576; # 1M
}

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        @_,

        #		files			=> [],
        #		dir			=> undef,
        #		mets_name		=> undef,
        #		mets_xml		=> undef,
    );
    $self->{outfile} = $self->{volume}->get_mets_path();

    return $self;
}

sub run {
    my $self = shift;
    my $mets = new METS( objid => $self->{volume}->get_identifier() );
    $self->{'mets'}    = $mets;
    $self->{'amdsecs'} = [];

    $self->_add_schemas();
    $self->_add_header();
    $self->_add_dmdsecs();
    $self->_add_techmds();
    $self->_add_filesecs();
    $self->_add_struct_map();
    $self->_add_premis();
    $self->_add_amdsecs();
    $self->_save_mets();
    $self->_validate_mets();
    $self->_set_done();

}

sub stage_info {
    return { success_state => 'metsed', failure_state => 'punted' };
}

sub _add_schemas {
    my $self = shift;
    my $mets = $self->{mets};

    $mets->add_schema( "PREMIS", NS_PREMIS, SCHEMA_PREMIS );
    $mets->add_schema( "MARC",   NS_MARC,   SCHEMA_MARC );

}

sub _add_header {
    my $self = shift;
    my $mets = $self->{mets};

    my $header = new METS::Header(
        createdate   => _get_createdate(),
        recordstatus => 'NEW',
        id           => 'HDR1',
    );
    $header->add_agent(
        role => 'CREATOR',
        type => 'ORGANIZATION',
        name => 'DLPS'
    );

    $mets->set_header($header);

    # Google: altRecordID handling - reject if there is an altRecordID in the
    # source METS. This should only happen if the volume is a duplicate, which
    # should be detected by looking for condition 31 set and source library
    # bibkey not null, but it doesn't hurt to check.

    # IA: add an altRecordID with the IA identifier
    return $header;
}

sub _add_dmdsecs {
    my $self   = shift;
    my $volume = $self->{volume};
    my $mets   = $self->{mets};

    # TODO: validate/remediate MARC
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

    $dmdsec =
      new METS::MetadataSection( 'dmdSec',
        'id' => $self->_get_subsec_id("DMD") );
    $dmdsec->set_data(
        $volume->get_marc_xml(),    # will throw an exception if no MARC found
        mdtype => 'MARC',
        label  => 'Physical volume MARC record'
    );
    $mets->add_dmd_sec($dmdsec);

    # MIU: add TEIHDR; do not add second call number??
}

sub _add_techmds {

    # Google: notes.txt and pagedata.txt should no longer be present

    # MIU: loadcd.log, checksum, pageview.dat, target files?

    # UMP: PDF????!?!?!?

}

# extract existing PREMIS events from object currently in repos
sub _extract_old_premis {
    my $self   = shift;
    my $volume = $self->{volume};

    my $mets_in_repos = $volume->get_repository_mets_path();
    my $old_events    = {};

    if ( defined $mets_in_repos ) {

        # validate METS in repository
        my ( $mets_in_rep_valid, $val_results ) =
          $self->validate_xml($mets_in_repos);
        if ($mets_in_rep_valid) {
            my $xc = $volume->get_repos_mets_xpc();

            foreach my $event ( $xc->findnodes('//premis:event') ) {

                my $eventType = $xc->findvalue( "./premis:eventType", $event );
                my $eventId = $xc->findvalue(
                    "./premis:eventIdentifier/premis:eventIdentifierValue",
                    $event );

                # TODO: upgrade to UUID if eventIdentifierType is not UUID

                $self->set_error(
                    "MissingField",
                    field => "eventType",
                    node  => $event->toString()
                ) unless defined $eventType and $eventType;
                $self->set_error(
                    "MissingField",
                    field => "eventIdentifierValue",
                    node  => $event->toString()
                ) unless defined $eventId and $eventId;

                $old_events->{$eventId} = $event;
            }

            return $old_events;

        }
        else {

            # TODO: should be warning, not error
            $self->set_error(
                "BadFile",
                file   => $mets_in_repos,
                detail => $val_results
            );
            print "$val_results";
            return 0;
        }
    }
}

sub _add_premis_events {
    my $self            = shift;
    my $events          = shift;
    my $premis          = $self->{premis};
    my $volume          = $self->{volume};
    my $nspkg           = $volume->get_nspkg();

    EVENTCODE: foreach my $eventcode ( @{$events} ) {

        # query database for: datetime, outcome
        my $eventconfig = $nspkg->get_event_configuration($eventcode);
        my ( $eventid, $datetime, $outcome ) =
          $volume->get_event_info($eventcode);
        $eventconfig->{eventid} = $eventid;
        $eventconfig->{date} = $datetime;
        if(defined $outcome) {
            $eventconfig->{outcomes} = [$outcome];
        }

        # already have event? if so, don't add it again

        $self->add_premis_event($eventconfig);


    }

}

sub add_premis_event {
    my $self = shift;
    my $eventconfig = shift;
    my $volume = $self->{volume};
    my $premis = $self->{premis};
    my $included_events = $self->{included_events};

    foreach my $field ('executor','executor_type','detail','type','date','eventid') {
        if(not defined $eventconfig->{$field}) {
            $self->set_error("MissingField",
                field => $field,
		actual => $eventconfig
            );
            return;
        }
    }
    
    # make sure we haven't already added this event
    my $eventid = $eventconfig->{'eventid'};
    if (defined $included_events->{$eventid}) {
        return;
    } 

    my $event = new PREMIS::Event( $eventconfig->{'eventid'}, 'UUID', 
                                   $eventconfig->{'type'}, $eventconfig->{'date'},
                                   $eventconfig->{'detail'});
    foreach my $outcome (@{ $eventconfig->{'outcomes'} }) {
        $event->add_outcome($outcome);
    }

# query namespace/packagetype for software tools to record for this event type
    $event->add_linking_agent(
        new PREMIS::LinkingAgent( $eventconfig->{'executor_type'}, 
                                  $eventconfig->{'executor'}, 
                                  'Executor' ) );

    my @agents       = ();
    my $tools_config = $eventconfig->{'tools'};
    foreach my $agent (@$tools_config) {
        $event->add_linking_agent(
            new PREMIS::LinkingAgent( 'tool', $self->get_tool_version($agent), 'software')
        );
    }
    $included_events->{$eventid} = $event;
    $premis->add_event($event);

    return $event;
}

# Baseline source METS extraction for cases where source METS PREMIS events
# need no modification for inclusion into HT METS

sub _add_source_mets_events {
    my $self   = shift;
    my $volume = $self->{volume};
    my $premis = $self->{premis};

    my $xc                = $volume->get_source_mets_xpc();
    my $src_premis_events = {};
    foreach my $src_event ( $xc->findnodes('//premis:event') ) {

        # src event will be an XML node
        # do we want to keep this kind of event?
        my $event_type = $xc->findvalue( './premis:eventType', $src_event );
        $src_premis_events->{$event_type} = []
          if not defined $src_premis_events->{$event_type};
        push( @{ $src_premis_events->{$event_type} }, $src_event );
    }

    foreach my $eventtype (
        @{ $volume->get_nspkg()->get('source_premis_events_extract') } )
    {
        next unless defined $src_premis_events->{$eventtype};
        foreach my $src_event ( @{ $src_premis_events->{$eventtype} } ) {
            my $eventid = $xc->findvalue( "./premis:eventIdentifier[premis:eventIdentifierType='UUID']/premis:eventIdentifierValue",
                $src_event
            );
            if ( not defined $self->{included_events}{$eventid} ) {
                $self->{included_events}{$eventid} = $src_event;
                $premis->add_event($src_event);
            }
        }
    }
}

sub _add_premis {
    my $self   = shift;
    my $volume = $self->{volume};
    my $nspkg  = $volume->get_nspkg();

    # map from UUID to event - events that have already been added
    $self->{included_events} = {};

    my $premis = new PREMIS;
    $self->{premis} = $premis;

    my $old_events = $self->_extract_old_premis();
    if ($old_events) {
        while ( my ( $eventid, $event ) = each(%$old_events) ) {
            $self->{included_events}{$eventid} = $event;
            $premis->add_event($event);
        }
    }

    $self->_add_source_mets_events();

    # create PREMIS object
    my $premis_object =
      new PREMIS::Object( 'identifier', $volume->get_identifier() );
    $premis_object->set_preservation_level("1");
    $premis_object->add_significant_property( 'file count',
        $volume->get_file_count() );
    if ($volume->get_file_groups()->{image}) {
        $premis_object->add_significant_property( 'page count',
            $volume->get_page_count() );
    }
    $premis->add_object($premis_object);

    # last chance to record, even though it's not done yet
    $volume->record_premis_event('ingestion');

    $self->_add_premis_events( $nspkg->get('premis_events') );

    my $digiprovMD =
      new METS::MetadataSection( 'digiprovMD', 'id' => 'premis1' );
    $digiprovMD->set_xml_node( $premis->to_node(), mdtype => 'PREMIS' );

    push( @{ $self->{amd_mdsecs} }, $digiprovMD );

}

sub _add_amdsecs {
    my $self = shift;
    $self->{'mets'}
      ->add_amd_sec( $self->_get_subsec_id("AMD"), @{ $self->{amd_mdsecs} } );

}

sub _get_subsec_id {
    my $self        = shift;
    my $subsec_type = shift;
    $self->{counts} = {} if not exists $self->{counts};
    $self->{counts}{$subsec_type} = 0
      if not exists $self->{counts}{$subsec_type};
    return "$subsec_type" . ++$self->{counts}{$subsec_type};
}

sub _add_zip_fg {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    $volume->record_premis_event('zip_md5_create');
    my $zip_filegroup = new METS::FileGroup(
        id  => $self->_get_subsec_id("FG"),
        use => 'zip archive'
    );
    my ($zip_path,$zip_name) = $volume->get_zip_path();
    $zip_filegroup->add_file( $zip_name, path => $zip_path, prefix => 'ZIP' );
    $mets->add_filegroup($zip_filegroup);
}

sub _add_content_fgs {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    # then add the actual content files
    my $filegroups = $volume->get_file_groups();
    $self->{filegroups} = {};
    while ( my ( $filegroup_name, $filegroup ) = each(%$filegroups) ) {
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

sub _add_filesecs {
    my $self = shift;

    # first add zip
    $self->_add_zip_fg();
    $self->_add_content_fgs();

    # MIU: Extra stuff for MIU: archival XML, objid XML?

}

sub _add_struct_map {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $struct_map = new METS::StructMap( id => 'SM1', type => 'physical' );
    my $voldiv = new METS::StructMap::Div( type => 'volume' );
    $struct_map->add_div($voldiv);
    my $order               = 1;
    my $file_groups_by_page = $volume->get_file_groups_by_page();
    foreach my $seqnum ( sort( keys(%$file_groups_by_page) ) ) {
        my $pagefiles   = $file_groups_by_page->{$seqnum};
        my $pagediv_ids = [];
        my $pagedata;
        my @pagedata;
        while ( my ( $filegroup_name, $files ) = each(%$pagefiles) ) {
            foreach my $file (@$files) {
                my $fileid =
                  $self->{filegroups}{$filegroup_name}->get_file_id($file);
                if ( not defined $fileid ) {
                    $self->set_error(
                        "MissingField",
                        field     => "fileid",
                        file      => $file,
                        filegroup => $filegroup_name,
                        detail    => "Can't find ID for file in file group"
                    );
                    next;
                }

                # try to find page number & page tags for this page
                if ( not defined $pagedata ) {
                    $pagedata = $volume->get_page_data($file);
                    @pagedata = %$pagedata;
                }
                else {
                    my $other_pagedata = $volume->get_page_data($file);
                    while ( my ( $key, $val ) = each(%$pagedata) ) {
                        my $val1 = $other_pagedata->{$key};
                        $self->set_error(
                            "NotEqualValues",
                            actual => "other=$val ,$fileid=$val1",
                            detail =>
"Mismatched page data for different files in pagefiles"
                          )
                          unless ( not defined $val and not defined $val1 )
                          or ( $val eq $val1 );
                    }

                }

                push( @$pagediv_ids, $fileid );
            }
        }
        $voldiv->add_file_div(
            $pagediv_ids,
            order => $order++,
            type  => 'page',
            @pagedata
        );
    }
    $mets->add_struct_map($struct_map);

}

sub _save_mets {
    my $self = shift;
    my $mets = $self->{mets};

    my $mets_path = $self->{outfile};

    open( my $metsxml, ">", "$mets_path" )
      or die("Can't open METS xml $mets_path for writing: $!");
    print $metsxml $mets->to_node()->toString(1);
    close($metsxml);
}

sub _validate_mets {
    my $self      = shift;
    my $mets_path = $self->{outfile};

    croak("File $mets_path does not exist. Cannot validate.")
      unless -e $mets_path;

    my ( $mets_valid, $val_results ) = $self->validate_xml($mets_path);
    if ( !$mets_valid ) {
        $self->set_error(
            "BadFile",
            file   => $mets_path,
            detail => "XML validation error: $val_results"
        );

        # TODO: set failure creating METS file
        return;
    }

}

sub validate_xml {
    my $self   = shift;
    my $xerces = get_config('xerces');

    my $filename       = shift;
    my $validation_cmd = "$xerces -f -p $filename 2>&1";
    my $val_results    = `$validation_cmd`;
    if ( $val_results =~ /Error/ || $? ) {
        wantarray ? return ( 0, $val_results ) : return (0);
    }
    else {
        wantarray ? return ( 1, undef ) : return (0);
    }

}

=item _get_createdate $ss1970

Given ss1970, use Time::localtime to generate a date with format: yyyy-mm-ddT13:27:00

=cut

sub _get_createdate {
    my $self   = shift;
    my $ss1970 = shift;

    my $localtime_obj = defined($ss1970) ? localtime($ss1970) : localtime();

    my $ts = sprintf(
        "%d-%02d-%02dT%02d:%02d:%02d",
        ( 1900 + $localtime_obj->year() ), ( 1 + $localtime_obj->mon() ),
        $localtime_obj->mday(), $localtime_obj->hour(),
        $localtime_obj->min(),  $localtime_obj->sec()
    );

    return $ts;
}

# Getting software versions

=item git_revision() 

Returns the git revision of the currently running script

=cut

sub git_revision {
    my $self = shift;
    my $path =
      dirname( abs_path(__FILE__) )
      ;    # get path to this file, hope it's in a git repo
    my $scriptname = basename($0);
    my $gitrev = `cd $path; git rev-parse HEAD`;
    chomp $gitrev if defined $gitrev;

    if ( !$? and defined $gitrev and $gitrev =~ /^[0-9a-f]{40}/ ) {
        return "$scriptname git rev $gitrev";
    }
    else {
        $self->set_error( 'ToolVersionError',
            detail => "Can't get git revision for $0: git returned '$gitrev' with status $?");
        return "$scriptname";
    }

}

=item perl_mod_version($module)

Returns $module::VERSION; $module must have already been loaded.

=cut

sub perl_mod_version() {
    my $self    = shift;
    my $module  = shift;
    my $mod_req = $module;
    $mod_req =~ s/::/\//g;
    my $toreturn;
    eval { require "$mod_req.pm"; };
    if ($@) {
        $self->set_error( 'ToolVersionError',
            detail => "Error loading $module: $@" );
        return "$module";
    }
    no strict 'refs';
    my $version = ${"${module}::VERSION"};
    if ( defined $version ) {
        return "$module $version";
    }
    else {
        $self->set_error( 'ToolVersionError',
            detail => "Can't find ${module}::VERSION" );
        return "$module";
    }
}

=item local_directory_version($package)

Returns the version of a package installed in a local directory hierarchy,
specified by the 'premis_tool_local' configuration directive

=cut

sub local_directory_version() {
    my $self      = shift;
    my $package   = shift;
    my $tool_root = get_config("premis_tool_local");
    if ( not -l "$tool_root/$package" ) {
        $self->set_error( 'ToolVersionError',
            detail => "$tool_root/$package not a symlink" );
        return $package;
    }
    else {
        my $package_target;
        if ( !( $package_target = readlink("$tool_root/$package") ) ) {
            $self->set_error( 'ToolVersionError',
                detail => "Error in readlink for $tool_root/$package: $!" )
              if $!;
            return $package;
        }

        my ($package_version) = ( $package_target =~ /$package-([\w.]+)$/ );
        if ($package_version) {
            return "$package $package_version";
        }
        else {
            $self->set_error( 'ToolVersionError',
                detail => "Couldn't extract version from symlink $package_version for $package");
            return $package;
        }

    }
}

=item system_version($package)

Returns the version of a system-installed RPM package.

=cut

sub system_version() {
    my $self    = shift;
    my $package = shift;
    my $version = `rpm -q $package`;

    if ( $? or $version !~ /^$package[-.\w]+/ ) {
        $self->set_error( 'ToolVersionError',
            detail =>
              "RPM returned '$version' with status $? for package $package" );
        return $package;
    }
    else {
        chomp $version;
        return $version;
    }
}

=item get_tool_version($package_identifier)

Gets the version of a tool defined in the premis_tools section in the configuration file.

=cut

sub get_tool_version {

    my $self       = shift;
    my $package_id = shift;
    my $to_eval    = get_config( 'premis_tools', $package_id );
    if ( !$to_eval ) {
        $self->set_error( 'ToolVersionError',
            detail => "$package_id missing from premis_tools" );
        return $package_id;
    }

    my $version = eval($to_eval);
    if ( $@ or !$version ) {
        $self->set_error( 'ToolVersionError', detail => $@ );
        return $package_id;
    }
    else {
        return $version;
    }
}

sub clean_always {
    my $self = shift;

    #$self->clean_ram_download();
    $self->clean_unpacked_object();
}

# do cleaning that is appropriate after failure
sub clean_failure {
    my $self = shift;
    $self->clean_mets();
}

# fixes errors in MARC leader by changing fields to their default value if they
# do not match the regular expression for the leader in the MARC schema
sub _remediate_marc {
    my $self = shift;
    my $xc = shift;

    my @leaders = $xc->findnodes("//marc:leader");
    if(@leaders != 1) {
        $self->set_error("BadField",field=>"marc:leader",detail=>"Zero or more than one leader found");
        return;
    }

    my $leader = $leaders[0];
    my $value = $leader->findvalue(".");

    if ($value !~ /^
        [\d ]{5} # 00-04: Record length
        [\dA-Za-z ]{1} # 05: Record status
        [\dA-Za-z]{1} # 06: Type of record
        [\dA-Za-z ]{3} # 07: Bibliographic level
                       # 08: Type of control
                       # 09: Character
        (2| )          # 10: Indicator count
        (2| )          # 11: Subfield code count
        [\d ]{5}       # 12: Base address of data
        [\dA-Za-z ]{3} # 17: Encoding level
                       # 18: Descriptive cataloging form
                       # 19: Multipart resource record level
        (4500|    )    # 20: Length of the length-of-field portion
                       # 21: Length of the starting-character-position portion
                       # 22: Length of the implementation-defined portion
                       # 23: Undefined
        $/x) {

        # 00-04: Record length - default to empty
        if(substr($value,0,5) !~ /^[\d ]{5}$/) {
            substr($value,0,5) = '     ';
        }

        # 05: Record status
        if(substr($value,5,1) !~ /^[\dA-Za-z ]$/) {
            substr($value,5,1) = ' ';
        }

        # 06: Type of record
        if(substr($value,6,1) !~ /^[\dA-Za-z]$/) {
            $logger->warn("Invalid value found for record type, can't remediate");
        }

        # 07: Bibliographic level
        if(substr($value,7,1) !~ /^[\dA-Za-z ]$/) {
            substr($value,7,1) = ' ';
        }

        # 08: Type of control
        if(substr($value,8,1) !~ /^[\dA-Za-z ]$/) {
            substr($value,8,1) = ' ';
        }

        # 09: Character coding scheme
        if(substr($value,9,1) ne 'a') {
            $logger->warn("Non-Unicode MARC-XML found");
        }

        # 10: Indicator count
        if(substr($value,10,1) !~ /^(2| )$/) {
            substr($value,10,1) = ' ';
        }

        # 11: Subfield code count
        if(substr($value,11,1) !~ /^(2| )$/) {
            substr($value,11,1) = ' ';
        }

        # 12-16: Base address of data
        if(substr($value,12,5) !~ /^[\d ]{5}$/) {
            substr($value,12,5) = '     ';
        }

        # 17: Encoding level
        if(substr($value,17,1) !~ /^[\dA-Za-z ]$/) {
            substr($value,17,1) = 'u'; # unknown
        }

        # 18: Descriptive cataloging form
        if(substr($value,18,1) !~ /^[\dA-Za-z ]$/) {
            substr($value,18,1) = 'u'; # unknown
        }

        # 19: Multipart resource record level
        if(substr($value,19,1) !~ /^[\dA-Za-z ]$/) {
            substr($value,19,1) = ' '; 
        }

        # 20: Length of the length-of-field portion
        # 21: Length of the start-character-position portion
        # 22: Length of the implementatino-defined portion
        # 23: Undefined
        if(substr($value,20,4) !~ /^(4500|    )/) {
            # default to unspecified
            substr($value,20,4) = '    ';
        }

        $leader->removeChildNodes();
        $leader->appendChild($leader->ownerDocument->createTextNode($value));
    }


}

1;
