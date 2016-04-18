#!/usr/bin/perl

package HTFeed::METS;
use strict;
use warnings;
use METS;
use PREMIS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use Carp;
use Log::Log4perl qw(get_logger);
use Time::gmtime;
use Cwd qw(cwd abs_path);
use HTFeed::Config qw(get_config get_tool_version);
use Date::Manip;
use File::Basename qw(basename dirname);
use FindBin;
use HTFeed::Version;
use Scalar::Util qw(blessed);

use base qw(HTFeed::Stage);

# TODO: remove after uplift
# Everything else should be covered by digitization?
my %agent_mapping = (
  'Ca-MvGOO' => 'google',
  'CaSfIA' => 'archive',
  'MiU' => 'umich',
  'MnU' => 'umn',
  'GEU' => 'emory',
  'GEU-S' => 'emory',
  'GEU-T' => 'emory',
  'TxCM' => 'tamu',
  'DeU' => 'udel',
  'IU' => 'illinois'
);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        is_uplift => 0,
        @_,

        #		files			=> [],
        #		dir			=> undef,
        #		mets_name		=> undef,
        #		mets_xml		=> undef,
    );
    $self->{outfile} = $self->{volume}->get_mets_path();
    # by default use volume "get_pagedata" to apply pagedata
    $self->{pagedata} = sub { $self->{volume}->get_page_data(@_); };
    $self->{premis} = new PREMIS;
    $self->{old_event_types} = {};
    $self->{profile} = get_config('mets_profile');
    $self->{required_events} = ["capture","message digest calculation","fixity check","validation","ingestion"];

    return $self;
}

sub run {
    my $self = shift;
    my $mets = new METS( objid => $self->{volume}->get_identifier(),
                         profile => $self->{profile} );
    $self->{'mets'}    = $mets;
    $self->{'amdsecs'} = [];

    $self->_add_schemas();
    $self->_add_header();
    $self->_add_dmdsecs();
    $self->_add_techmds();
    $self->_add_sourcemd();
    $self->_add_filesecs();
    $self->_add_struct_map();
    $self->_add_premis();
    $self->_add_amdsecs();
    $self->_check_premis();
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

}

sub _add_header {
    my $self = shift;
    my $mets = $self->{mets};

    my $header;

    if($self->{is_uplift}) {
        my $volume = $self->{volume};
        my $xc = $volume->get_repository_mets_xpc();
        my $createdate = $xc->findvalue('//mets:metsHdr/@CREATEDATE');
        if(not defined $createdate or !$createdate) {
            $self->setError('BadValue',field=>'//metsHdr/@CREATEDATE',
                detail=>"can't get METS creation time",
                file=>$volume->get_repository_mets_path());
        }
        # time stamp w/o timezone in METS creation date
        if($createdate =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/) {
            $createdate = $self->convert_tz($createdate,'America/Detroit');
        }
        $header = new METS::Header(
            createdate => $createdate,
            lastmoddate => _get_createdate(),
            recordstatus => 'REV',
            id => 'HDR1',
        );
    } else {
        $header = new METS::Header(
            createdate   => _get_createdate(),
            recordstatus => 'NEW',
            id           => 'HDR1',
        );
    }
    $header->add_agent(
        role => 'CREATOR',
        type => 'ORGANIZATION',
        name => get_config('mets_header_agent_name'),
    );

    $mets->set_header($header);

    return $header;
}

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
        otherloctype => 'Item ID stored in HathiTrust Metadata Management System',
        xptr         => $volume->get_identifier()
    );
    $mets->add_dmd_sec($dmdsec);

}

# no techmds by default
sub _add_techmds {
    my $self = shift;
}

# generate info from feed_zephir_items and ht_collections table, or throw error if it's missing.
sub _add_sourcemd {

    sub element_ht {
        my $name = shift;
        my %attributes = @_;
        my $element = XML::LibXML::Element->new($name);
        $element->setNamespace(NS_HT,'HT');
        while (my ($attr,$val) = each %attributes) {
            $element->setAttribute($attr,$val);
        }
        return $element;
    }

    my $self = shift;

    my ($content_providers,$responsible_entity,$digitization_agents) = $self->{volume}->get_sources();
    my $format = 'digitized';
    $format = 'borndigital' if not defined $digitization_agents or $digitization_agents eq '';

    my $sources = element_ht("sources", format => $format);

    my $sourcemd = METS::MetadataSection->new( 'sourceMD',
        id => $self->_get_subsec_id('SMD'));

    $self->_format_source_element($sources,'contentProvider', $content_providers);
    $self->_format_source_element($sources,'digitizationAgent', $digitization_agents) if $digitization_agents;

    # add responsible entity
    # FIXME: how to add 2nd responsible entity?
    my $responsible_entity_element = element_ht('responsibleEntity',sequence => '1');
    $responsible_entity_element->appendText($responsible_entity);
    $sources->appendChild($responsible_entity_element);

    $sourcemd->set_data($sources, mdtype => 'OTHER', othermdtype => 'HT');
    push(@{ $self->{amd_mdsecs} },$sourcemd);

}

sub _format_source_element {
  my $self = shift;
  my $source_element = shift;
  my $element_name = shift;
  my $source_agentids = shift;

  # make sure one content provider is selected for display
  $source_agentids = "$source_agentids*" if $source_agentids !~ /\*/;
  foreach my $agentid (split(';',$source_agentids)) {
    my $sequence = 0;
    $sequence++;
    my $display = 'no';
    if($agentid =~ /\*$/) {
      $display = 'yes';
      $agentid =~ s/\*$//;
    }

    # add element
    my $element = undef;
    if($element_name eq 'contentProvider') {
      $element = element_ht($element_name, sequence => $sequence, display => $display);
    } elsif ($element_name eq 'digitizationAgent') { 
      # order doesn't matter for digitization source
      $element = element_ht($element_name, display => $display);
    } else {
      die("Unexpected source element $element_name");
    }
    $element->appendText($agentid);
    $source_element->appendChild($element);
  }
}

sub _update_event_date {
    my $self = shift;

    my $event = shift;
    my $xc = shift;
    my $eventinfo = shift;
    my $date = $eventinfo->{date};

    my $volume = $self->{volume};

    if($date =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/) {
        my $from_tz = $volume->get_nspkg()->get('default_timezone');

        if(not defined $from_tz or $from_tz eq '') {
            $self->set_error("BadField",field=>"eventDate",
                actual => $date, 
                detail => "Missing time zone for event date");
        }

        if(defined $from_tz) {
            $date = $self->convert_tz($date,$from_tz);
            my $eventdateTimeNode = ($xc->findnodes('./premis:eventDateTime',$event))[0];
            $eventdateTimeNode->removeChildNodes();
            $eventdateTimeNode->appendText($date);
        }
    } elsif($date =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$/) {
        # Date::Manip 5 will parse using the offset to the equivalent time in
        # the default time zone, then convert from default TZ to UTC

        # Date::Manip 6 will use the included time zone information

        $date = $self->convert_tz($date,''); 
        my $eventdateTimeNode = ($xc->findnodes('./premis:eventDateTime',$event))[0];
        $eventdateTimeNode->removeChildNodes();
        $eventdateTimeNode->appendText($date);
    }

    return $date;
}

# extract existing PREMIS events from object currently in repos
sub _extract_old_premis {
    my $self   = shift;
    my $volume = $self->{volume};

    my $mets_in_repos = $volume->get_repository_mets_path();
    my $old_events = {};
    my $need_uplift_event = 0;

    if ( defined $mets_in_repos ) {

        my ( $mets_in_rep_valid, $val_results ) =
        $self->validate_xml($mets_in_repos);
        if ($mets_in_rep_valid) {
            # create map of event types to event details -- for use in updating old event details
            my %event_map = ();
            my $nspkg = $volume->get_nspkg();
            foreach my $eventconfig ( (@{ $nspkg->get('source_premis_events_extract') }, 
                                      @{ $nspkg->{packagetype}->get('premis_events') }, # underlying original events
                                      @{ $nspkg->get('premis_events') }) ) { # overridden events
                my $eventconfig_info = $nspkg->get_event_configuration($eventconfig);
                my $eventconfig_type = $eventconfig_info->{type};
                $event_map{$eventconfig_type} = $eventconfig_info->{detail};
            }

            my $xc = $volume->get_repository_mets_xpc();

            $self->migrate_agent_identifiers($xc);

            foreach my $event ( $xc->findnodes('//premis:event') ) {

                my $eventinfo = { 
                    eventtype => $xc->findvalue( "./premis:eventType", $event ) ,
                    eventid => $xc->findvalue( "./premis:eventIdentifier/premis:eventIdentifierValue", $event ),
                    eventidtype => $xc->findvalue(" ./premis:eventIdentifier/premis:eventIdentifierType", $event),
                    date => $xc->findvalue( "./premis:eventDateTime", $event ),
                };

                foreach my $field (qw(eventtype eventid date)) {
                    $self->set_error(
                        "MissingField",
                        field => "$field",
                        node  => $event->toString()
                    ) unless defined $eventinfo->{$field} and $eventinfo->{$field};
                }

                # migrate obsolete events
                my $migrate_events = $nspkg->get('migrate_events');
                my $new_event_tags = $migrate_events->{$eventinfo->{eventtype}};
                if(defined $new_event_tags) {
                    my $old_event_type = $eventinfo->{eventtype};
                    $new_event_tags = [$new_event_tags] unless ref($new_event_tags);
                    foreach my $new_event_tag (@$new_event_tags) {
                        my $new_event = $event->cloneNode(1);

                        my $new_eventinfo = $nspkg->get_event_configuration($new_event_tag);

                        # update eventType,eventDetail
                        my $eventtype_node = ($xc->findnodes("./premis:eventType",$new_event))[0];
                        $eventtype_node->removeChildNodes();
                        $eventtype_node->appendText($new_eventinfo->{type});
                        $eventinfo->{eventtype} = $new_eventinfo->{type};

                        my $eventdetail_node = ($xc->findnodes("./premis:eventDetail",$new_event))[0];
                        $eventdetail_node->removeChildNodes();
                        $eventdetail_node->appendText($new_eventinfo->{detail});

                        # update eventDate
                        my $new_date = $self->_update_event_date($new_event,$xc,$eventinfo);

                        # create new event UUID
                        my $uuid = $volume->make_premis_uuid($new_eventinfo->{type},$new_date);
                        my $eventidval_node = ($xc->findnodes("./premis:eventIdentifier/premis:eventIdentifierValue",$new_event))[0];
                        $eventidval_node->removeChildNodes();
                        $eventidval_node->appendText($uuid);

                        my $eventidtype_node = ($xc->findnodes("./premis:eventIdentifier/premis:eventIdentifierType",$new_event))[0];
                        $eventidtype_node->removeChildNodes();
                        $eventidtype_node->appendText('UUID');
                        
                        $old_events->{$uuid} = $new_event;
                        $self->{old_event_types}->{$new_eventinfo->{type}} = $event;
                        $need_uplift_event = 1;
                        get_logger()->info("Migrated $old_event_type event to $new_eventinfo->{type}");
                    }
                } else {

                    # update eventDetail
                    my $eventdetail_node = ($xc->findnodes("./premis:eventDetail",$event))[0];
                    my $newtext = $event_map{$eventinfo->{eventtype}};
                    if(defined $eventdetail_node) {
                        my $text = $eventdetail_node->textContent();
                        if(defined $newtext
                                and $newtext ne $text) {
                            $eventdetail_node->removeChildNodes();
                            $eventdetail_node->appendText($event_map{$eventinfo->{eventtype}});
                            $need_uplift_event = 1;
                            get_logger()->info("Updated detail for $eventinfo->{eventtype} from '$text' to '$newtext'");
                        }
                    } else {
                        # eventDetail node may be missing in some cases e.g. audio manual quality inspection :(
                        if(not defined $newtext) {
                            $self->set_error("BadField",field => 'eventDetail', detail => "Missing eventDetail for $eventinfo->{eventtype}");
                        }
                        my $eventDateTime = ($xc->findnodes("./premis:eventDateTime",$event))[0];
                        if(not defined $eventDateTime) {
                            $self->set_error("BadField",field => 'eventDateTime', detail => "Missing eventDateTime for $eventinfo->{eventtype}");
                        }
                        $eventDateTime->parentNode()->insertAfter(PREMIS::createElement( "eventDetail", $newtext ),
                                                                $eventDateTime);
                    }

                    # update eventDate
                    my $event_date = $self->_update_event_date($event,$xc,$eventinfo);

                    # update event UUID
                    my $uuid = $volume->make_premis_uuid($eventinfo->{eventtype},$event_date);
                    my $update_eventid = 0;
                    if($eventinfo->{eventidtype} ne 'UUID') {
                        get_logger()->info("Updating old event ID type $eventinfo->{eventidtype} to UUID for $eventinfo->{eventtype}/$eventinfo->{date}");
                        $need_uplift_event = 1;
                        $update_eventid = 1;
                    } elsif($eventinfo->{eventid} ne $uuid) {
                        # UUID may change if it was originally computed incorrectly
                        # or if the time zone is now included in the date
                        # calculation.
                        get_logger()->warn("Warning: calculated UUID for $eventinfo->{eventtype} on $eventinfo->{date} did not match saved UUID; updating.");
                        $need_uplift_event = 1;
                        $update_eventid = 1;
                    }

                    if($update_eventid) {
                        my $eventidval_node = ($xc->findnodes("./premis:eventIdentifier/premis:eventIdentifierValue",$event))[0];
                        $eventidval_node->removeChildNodes();
                        $eventidval_node->appendText($uuid);
                        my $eventidtype_node = ($xc->findnodes("./premis:eventIdentifier/premis:eventIdentifierType",$event))[0];
                        $eventidtype_node->removeChildNodes();
                        $eventidtype_node->appendText('UUID');
                    }

                    $self->{old_event_types}->{$eventinfo->{eventtype}} = $event;
                    $old_events->{$uuid} = $event;
                }

            }
        } else {
             $self->set_error(
                 "BadFile",
                 file   => $mets_in_repos,
                 detail => $val_results
             );
        }
            
#        # at a minimum there should be capture, message digest calculation,
#        # fixity check, validation and ingestion.
#        if($volume->get_packagetype() ne 'audio') {
#            foreach my $required_event_type ("capture","message digest calculation","fixity check","validation","ingestion") {
#                $self->set_error("BadField",detail=>"Could not extract old PREMIS event",
#                    field=>"premis event $required_event_type",file=>$mets_in_repos)
#                if not defined $self->{old_event_types}->{$required_event_type};
#            }
#        }

        if($need_uplift_event) {
            $volume->record_premis_event('premis_migration');
        }
        return $old_events;

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
        my ( $eventid, $datetime, $outcome,$custom ) =
        $volume->get_event_info($eventcode);
        if(defined $custom) {
            $premis->add_event($custom);
        } elsif(defined $eventid) {
            $eventconfig->{eventid} = $eventid;
            $eventconfig->{date} = $datetime;
            if(defined $outcome) {
                $eventconfig->{outcomes} = [$outcome];
            }
            $self->add_premis_event($eventconfig);
        } elsif (not defined $eventconfig->{optional} or !$eventconfig->{optional}) {
            $self->set_error("MissingField",field=>"premis_$eventcode",detail=>"No PREMIS event recorded with config ID $eventcode");
        }
    }

}

sub _get_event_type {
  my $event = shift;

  if (blessed($event) and $event->isa("PREMIS::Event") and defined $event->{event_type}) { 
    return $event->{event_type};
  } elsif (blessed($event) and $event->isa("XML::LibXML::Element") ) {
    my $xc = XML::LibXML::XPathContext->new($event);
    register_namespaces($xc);
    return $xc->findvalue( './premis:eventType', $event );
  } else {
    return undef;
  }

}

sub _check_premis {
  my $self = shift;
  my $volume = $self->{volume};

  my %included_event_types = map { (_get_event_type($_),1) } values( %{$self->{included_events}} );
  # at a minimum there should be capture, message digest calculation,
  # fixity check, validation and ingestion.
  if($volume->get_packagetype() ne 'audio') {
      foreach my $required_event_type (@{$self->{required_events}}) {
          $self->set_error("BadField",detail=>"Missing required PREMIS event type",
              field=>"premis event $required_event_type")
          if not defined $included_event_types{$required_event_type};
      }
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
            new PREMIS::LinkingAgent( 'tool', get_tool_version($agent), 'software')
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
    $self->migrate_agent_identifiers($xc);

    my $src_premis_events = {};
    foreach my $src_event ( $xc->findnodes('//premis:event') ) {

        # src event will be an XML node
        # do we want to keep this kind of event?
        my $event_type = $xc->findvalue( './premis:eventType', $src_event );
        $src_premis_events->{$event_type} = []
        if not defined $src_premis_events->{$event_type};
        push( @{ $src_premis_events->{$event_type} }, $src_event );
    }

    foreach my $eventcode (
        @{ $volume->get_nspkg()->get('source_premis_events_extract') } )
    {
        my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
        my $eventtype = $eventconfig->{type};

        if(not defined $src_premis_events->{$eventtype}) {
            $self->set_error("MissingField", 
                field => "premis $eventtype", 
                file => $volume->get_source_mets_file(), 
                detail => "Missing required PREMIS event in source METS")
            unless (defined $eventconfig->{optional} and $eventconfig->{optional});
        }
        next unless defined $src_premis_events->{$eventtype};
        foreach my $src_event ( @{ $src_premis_events->{$eventtype} } ) {
            my $eventid = $xc->findvalue( "./premis:eventIdentifier[premis:eventIdentifierType='UUID']/premis:eventIdentifierValue",
                $src_event
            );

            # overwrite already-included event w/ updated information if needed
            $self->{included_events}{$eventid} = $src_event;
            $premis->add_event($src_event);
            
        }
    }
}

sub _add_premis {
    my $self   = shift;
    my $volume = $self->{volume};
    my $nspkg  = $volume->get_nspkg();

    # map from UUID to event - events that have already been added
    $self->{included_events} = {};

    my $premis = $self->{premis};

    my $old_events = $self->_extract_old_premis();
    if ($old_events) {
        while ( my ( $eventid, $event ) = each(%$old_events) ) {
            $self->{included_events}{$eventid} = $event;
            $premis->add_event($event);
        }
    }

    # don't re-add source METS events if this is an uplift
    if(!$self->{is_uplift}) {
        $self->_add_source_mets_events();
    }

    # create PREMIS object
    my $premis_object =
    new PREMIS::Object( 'HathiTrust', $volume->get_identifier() );
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
    my ($zip_path,$zip_name) = ($volume->get_zip_directory(), $volume->get_zip_filename());
    $zip_filegroup->add_file( $zip_name, path => $zip_path, prefix => 'ZIP' );
    $mets->add_filegroup($zip_filegroup);
}

sub _add_srcmets_fg {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    # Add source METS if it is present
    my $src_mets_file = $self->{volume}->get_source_mets_file();

    if($src_mets_file) {
        my $mets_filegroup = new METS::FileGroup(
            id  => $self->_get_subsec_id("FG"),
            use => 'source METS'
        );
        $mets_filegroup->add_file( $src_mets_file, 
            path => $volume->get_staging_directory(), 
            prefix => 'METS' );
        $mets->add_filegroup($mets_filegroup);
    }
}

sub _add_content_fgs {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    # then add the actual content files
    my $filegroups = $volume->get_file_groups();
    $self->{filegroups} = {};
    while ( my ( $filegroup_name, $filegroup ) = each(%$filegroups) ) {
        # ignore empty file groups
        next unless @{$filegroup->get_filenames()};
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
    $self->_add_srcmets_fg();
    $self->_add_content_fgs();

}

# Basic structMap with optional page labels.
sub _add_struct_map {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};
    my $get_pagedata = $self->{pagedata};

    my $struct_map = new METS::StructMap( id => 'SM1', type => 'physical' );
    my $voldiv = new METS::StructMap::Div( type => 'volume' );
    $struct_map->add_div($voldiv);
    my $order               = 1;
    my $file_groups_by_page = $volume->get_structmap_file_groups_by_page();
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

                if(defined $get_pagedata) {
                    # try to find page number & page tags for this page
                    if ( not defined $pagedata ) {
                        $pagedata = &$get_pagedata($file);
                        @pagedata = %$pagedata if defined $pagedata;
                    }
                    else {
                        my $other_pagedata = &$get_pagedata($file);
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
    my $use_caching = $self->{volume}->get_nspkg()->get('use_schema_caching');
    my $schema_cache = get_config('xerces_cache');
    my $xerces = get_config('xerces');

    $xerces .= " $schema_cache" if($use_caching);

    my $filename       = shift;
    my $validation_cmd = "$xerces '$filename' 2>&1";
    my $val_results    = `$validation_cmd`;
    if ( ($use_caching and $val_results !~ /\Q$filename\E OK/) or
        (!$use_caching and $val_results =~ /Error/) or
        $? ) {
        wantarray ? return ( 0, $val_results ) : return (0);
    }
    else {
        wantarray ? return ( 1, undef ) : return (0);
    }

}

# Given ss1970, use Time::gmtime to generate a date with format: yyyy-mm-ddT13:27:00
sub _get_createdate {
    my $self   = shift;
    my $ss1970 = shift;

    my $gmtime_obj = defined($ss1970) ? gmtime($ss1970) : gmtime();

    my $ts = sprintf(
        "%d-%02d-%02dT%02d:%02d:%02dZ",
        ( 1900 + $gmtime_obj->year() ), ( 1 + $gmtime_obj->mon() ),
        $gmtime_obj->mday(), $gmtime_obj->hour(),
        $gmtime_obj->min(),  $gmtime_obj->sec()
    );

    return $ts;
}

sub clean_always {
    my $self = shift;

    $self->{volume}->clean_unpacked_object();
}

# do cleaning that is appropriate after failure
sub clean_failure {
    my $self = shift;
    $self->{volume}->clean_mets();
}

# fixes errors in MARC leader by changing fields to their default value if they
# do not match the regular expression for the leader in the MARC schema
sub _remediate_marc {
    my $self = shift;
    my $xc = shift;

    foreach my $fakeleader ($xc->findnodes('.//marc:controlfield[@tag="LDR"]')) {
        $fakeleader->removeAttribute('tag');
        $fakeleader->setNodeName('leader');
    }

    # remove internal aleph stuff; save control fields for rearrangement
    my @controlfields = ();
    foreach my $controlfield ($xc->findnodes('.//marc:controlfield')) {
        $controlfield->parentNode()->removeChild($controlfield);
        if($controlfield->getAttribute('tag') =~ /^\d{2}[A-Z0-9]$/) {
            push(@controlfields,$controlfield);
        }
    }

    foreach my $datafield ($xc->findnodes('.//marc:datafield')) {
        if($datafield->getAttribute('tag') =~ /^[A-Z]{3}$/) {
            $datafield->parentNode()->removeChild($datafield);
        }
    }

    my @leaders = $xc->findnodes(".//marc:leader");
    if(@leaders != 1) {
        $self->set_error("BadField",field=>"marc:leader",detail=>"Zero or more than one leader found");
        return;
    }

    my $leader = $leaders[0];

    my $value = $leader->findvalue(".");

    $value =~ s/\^/ /g;

    if ($value !~ /^
        [\d ]{5}       # 00-04: Record length
        [\dA-Za-z ]{1} # 05: Record status
        [\dA-Za-z]{1}  # 06: Type of record
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

        # fix up material with record status of 'a' and no record type
        if(substr($value,5,2) eq 'a ') {
            substr($value,5,2) = ' a';
        }

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
            get_logger()->warn("Invalid value found for record type, can't remediate");
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
            get_logger()->warn("Non-Unicode MARC-XML found");
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
    }

    $leader->removeChildNodes();
    $leader->appendText($value);

    # reinsert control fields in the correct place
    while (my $controlfield = pop @controlfields) {
        $leader->parentNode()->insertAfter($controlfield,$leader);
    }

    foreach my $datafield ($xc->findnodes('.//marc:datafield')) {
        # ind1/ind2 might have nbsp or control characters instead of regular space
        # @i1 => @ind1
        # @i2 => @ind2
        my $attrs_to_move = {
            # clean ind1, ind2; move i{1,2} -> ind{1,2}
            'ind1' => 'ind1',
            'ind2' => 'ind2',
            'i1' => 'ind1',
            'i2' => 'ind2',
        };
        while (my ($old,$new) = each (%$attrs_to_move)) {
            if($datafield->hasAttribute($old)) {

                my $attrval = $datafield->getAttribute($old);
                # default to empty if value is invalid
                if($attrval !~ /^[\da-z ]{1}$/) {
                    $attrval = " ";
                }
                $datafield->removeAttribute($old);
                $datafield->setAttribute($new,$attrval);
            }
        }
    }

    foreach my $datafield ($xc->findnodes('.//marc:datafield[not(marc:subfield)]')) {
        # remove empty data fields
        $datafield->parentNode()->removeChild($datafield);
    }


}

sub convert_tz {
    my $self = shift;
    my $date = shift;
    my $from_tz = shift;
    die("No from_tz specified") unless defined $from_tz;

    die("Missing Date::Manip::VERSION") unless defined $Date::Manip::VERSION;
    if($Date::Manip::VERSION < 6.00) {
        # version 5 functional interface, doesn't track timezone
        my $parsed = ParseDate($date);
        $self->set_error("BadValue",actual=>"$date",field=>"date",detail=>"Can't parse date") unless defined $parsed;

        my $utc_date = Date_ConvTZ($parsed,$from_tz,'UTC');
        $self->set_error("BadValue",actual=>"$date $from_tz",field=>"date",detail=>"Can't convert to UTC") unless defined $utc_date;

        return UnixDate($utc_date,'%OZ');
    } else {
        # version 6 interface, much better with timezones
        my $dm_date = new Date::Manip::Date ("$date $from_tz");
        $self->set_error("BadValue",actual=>"$date $from_tz",field=>"date",detail=>"Can't parse date: " . $dm_date->err()) if $dm_date->err();

        $dm_date->convert('UTC');
        $self->set_error("BadValue",actual=>"$date $from_tz",field=>"date",detail=>"Can't convert to UTC: " . $dm_date->err()) if $dm_date->err();
        
        my $res = $dm_date->printf('%OZ');
        $self->set_error("BadValue",actual=>"$date $from_tz",field=>"date",detail=>"Can't convert to UTC: " . $dm_date->err()) if not defined $res or !$res;

        return $res;
    }
}

sub is_uplift {
    my $self = shift;
    return $self->{is_uplift};
}

sub agent_type {
  my $self = shift;
  my $agentid = shift;

  return "HathiTrust Institution ID";
}

# map MARC21 agent codes to HathiTrust Institution IDs 

sub migrate_agent_identifiers {
  my $self = shift;
  my $xc = shift;
  my $volume = $self->{volume};

  # migrate agent IDs
  #
  foreach my $agent ( $xc->findnodes('//premis:linkingAgentIdentifier') ) {
    my $agent_type = ($xc->findnodes('./premis:linkingAgentIdentifierType',$agent))[0];
    my $agent_value = ($xc->findnodes('./premis:linkingAgentIdentifierValue',$agent))[0];

    my $agent_type_text = $agent_type->textContent();
    my $agent_value_text = $agent_value->textContent();
    my $new_agent_value = undef;
    # TODO: remove after uplift
    if($agent_type_text eq 'MARC21 Code') {
      $new_agent_value = $agent_mapping{$agent_value_text};
      if(not defined $new_agent_value) {
        $self->set_error("BadValue",field=>'linkingAgentIdentifierValue',
          actual => $agent_value_text,
          detail => "Don't know what the HT institution ID is for MARC org code");
      }
    } elsif($agent_type_text eq 'HathiTrust AgentID') {
      if($agent_value_text eq 'UNKNOWN' and $volume->{namespace} = 'mdp') {
        # best guess
        $new_agent_value = 'umich';
      } else {
        $self->set_error("BadValue",field=>'linkingAgentIdentifierValue',
          actual => $agent_value_text,
          detail => 'Unexpected HathiTrust AgentID');
      }
    } elsif($agent_type_text eq 'HathiTrust Institution ID' or $agent_type_text eq 'tool') {
      # do nothing
    } else {
      my $mets_in_repos = $volume->get_repository_mets_path();
      $self->set_error("BadValue",field => 'linkingAgentIdentifierType',
        actual => $agent_type_text,
        expected => 'tool, MARC21 Code, or HathiTrust Institution ID',
        file => $mets_in_repos)
    }

    if(defined $new_agent_value) {
      $agent_type->removeChildNodes();
      $agent_type->appendText("HathiTrust Institution ID");
      $agent_value->removeChildNodes();
      $agent_value->appendText($new_agent_value);
    }
  }
}

1;

__END__

=head1 NAME

HTFeed::METS - Main class for creating METS XML

=head1 SYNOPSIS

A series of stages to generate a METS XML document for a Feed package.

=head1 DESCRIPTION 

METS.pm provides the main methods for generating a METS XML document.
These methods (documented below) can be subclassed for various special cases, such as SourceMETS and PackageType::METS.

=head2 METHODS

=over 4

=item new()

Instantiate the class

=item run()

Run a series of internally defined stages to generate the METS elements:

schemas

header

dmdsecs

techmds 

filesecs

struct_map

premis

amdsecs

The run() method also validates and saves the METS XML document.

=item perl_mod_version()

Return $module::VERSION; B<NOTE:> $module must have already been loaded.

C<$version = perl_mod_version($module);>

=item stage_info()

Return status on completion of METS stage (success/failure) 

=item add_premis_event()

Add a PREMIS event

=item local_directory_version()

Return the version of a package installed in a local directory hierarchy,
specified by the 'premis_tool_local' configuration directive

$local_version = local_directory_version($package);

=item system_version()

Return the version of a system-installed RPM package.

$package_version = system_version($package);

=item clean_always()

Do the cleaining that is appropriate for this stage.

=item validate_xml()

Validate the METS XML against the defined schema.

=item clean_failure()

Do the cleaning that is appropriate on stage failure.

=back

INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
