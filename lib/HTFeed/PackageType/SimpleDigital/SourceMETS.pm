#!/usr/bin/perl

package HTFeed::PackageType::SimpleDigital::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use Image::ExifTool;
use base qw(HTFeed::PackageType::Simple::SourceMETS);


sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};

    my $creation_date = $volume->get_meta('creation_date');
    $self->set_error('MissingValue',file=>'meta.yml',field=>'creation_date') unless defined $creation_date;

    my $eventcode = 'capture';
    my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
    $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$creation_date);
    $eventconfig->{'executor'} = $volume->get_meta('creation_agent');
    $self->set_error('MissingValue',file=>'meta.yml',field=>'creation_agent') unless defined $eventconfig->{'executor'};
    $eventconfig->{'executor_type'} = 'HathiTrust Institution ID';
    $eventconfig->{'date'} = $creation_date;
    my $creation_event = $self->add_premis_event($eventconfig);

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
        $eventconfig->{'executor_type'} = 'HathiTrust Institution ID';
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

    return $creation_event;
}

1;
