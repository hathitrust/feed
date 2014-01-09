#!/usr/bin/perl

package HTFeed::PackageType::Simple::SourceMETS;
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
    $self->{outfile} = "$stage_path/$pt_objid.mets.xml";
    $self->{pagedata} = sub { $volume->get_srcmets_page_data(@_); };
    $self->{volume}->record_premis_event('page_md5_fixity');

    return $self;
}


sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};

    my $capture_date = $volume->get_meta('capture_date');
    $self->set_error('MissingValue',file=>'meta.yml',field=>'capture_date') unless defined $capture_date;

    my $eventcode = 'capture';
    my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
    $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_date);
    $eventconfig->{'executor'} = $volume->get_meta('capture_agent');
    $eventconfig->{'executor_type'} = 'MARC21 Code';
    $eventconfig->{'date'} = $volume->get_meta('capture_date');
    my $event = $self->add_premis_event($eventconfig);
}

sub _add_dmdsecs {
    my $self = shift;
    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $preingest_directory = $volume->get_preingest_directory();
    $self->_add_marc_from_file("$preingest_directory/marc.xml");


}

1;
