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
    $self->set_error('MissingValue',file=>'meta.yml',field=>'capture_agent') unless defined $eventconfig->{'executor'};
    $eventconfig->{'executor_type'} = 'MARC21 Code';
    $eventconfig->{'date'} = $capture_date;
    my $capture_event = $self->add_premis_event($eventconfig);

    # also add image compression event if info present in meta.yml
    my $image_compression_date = $volume->get_meta('image_compression_date');
    my $image_compression_agent = $volume->get_meta('image_compression_agent');
    my $image_compression_tool = $volume->get_meta('image_compression_tool');
    if(defined $image_compression_date or defined $image_compression_agent or defined $image_compression_tool) {
        $self->set_error('MissingValue',file=>'meta.yml',field=>'image_compression_date') unless defined $image_compression_date;
        $self->set_error('MissingValue',file=>'meta.yml',field=>'image_compression_agent') unless defined $image_compression_agent;
        $self->set_error('MissingValue',file=>'meta.yml',field=>'image_compression_tool') unless defined $image_compression_tool;

        $eventconfig = $volume->get_nspkg()->get_event_configuration('image_compression');
        $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$image_compression_date);
        $eventconfig->{'executor'} = $image_compression_agent;
        $eventconfig->{'executor_type'} = 'MARC21 Code';
        $eventconfig->{'date'} = $image_compression_date;

        # make sure image compression tool is an array
        if(!ref($image_compression_tool) ) {
            $image_compression_tool = [$image_compression_tool];
        }
        if(ref($image_compression_tool) ne 'ARRAY') {
            $self->set_error('BadValue',file=>'meta.yml',field=>'image_compression_tool',expected=>'string or array',actual=>$image_compression_tool);
        }
        $eventconfig->{tools} = $image_compression_tool;
        
        $self->add_premis_event($eventconfig);
    }

    return $capture_event;
}

sub _add_dmdsecs {
    my $self = shift;
    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $preingest_directory = $volume->get_preingest_directory();
    $self->_add_marc_from_file("$preingest_directory/marc.xml");


}

1;
