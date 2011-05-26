#!/usr/bin/perl

package HTFeed::PackageType::UCM::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use Image::ExifTool;
use base qw(HTFeed::SourceMETS);


sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

    );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    $self->{outfile} = "$stage_path/UCM_" . $pt_objid . ".xml";

    return $self;
}


sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};

    # try to get the capture date for the first image
    # FIXME: placeholder
    my $capture_date = "1970-01-01T00:00:00Z";
    my $eventcode = 'capture';
    my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
    $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_date);
    $eventconfig->{'executor'} = 'SpMaUC';
    $eventconfig->{'executor_type'} = 'MARC21 Code';
    $eventconfig->{'date'} = $capture_date; 
    my $event = $self->add_premis_event($eventconfig);
}

sub _add_dmdsecs {
    # no descriptive metadata sections to add
    my $self = shift;

    return;
}

1;
