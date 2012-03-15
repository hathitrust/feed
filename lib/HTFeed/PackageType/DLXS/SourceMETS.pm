#!/usr/bin/perl

package HTFeed::PackageType::DLXS::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use base qw(HTFeed::SourceMETS);


sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

    );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    $self->{outfile} = "$stage_path/DLXS_" . $pt_objid . ".xml";

    return $self;
}



# TODO: get capture time from image ModifyDate or from 
# loadcd
sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};
    my $premis = $self->{premis};

    my $eventcode = 'capture';
    my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
    $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},"1970-01-01T00:00:00");
    $eventconfig->{'executor'} = 'MiU';
    $eventconfig->{'executor_type'} = 'MARC21 Code';
    # FOR TESTING ONLY
    $eventconfig->{'date'} = "1970-01-01T00:00:00";
    my $event = $self->add_premis_event($eventconfig);
}

1;
