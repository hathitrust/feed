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
    my $exifTool = new Image::ExifTool;
    $exifTool->ExtractInfo($volume->get_staging_directory() . "/00000001.jp2");
    my $capture_date = $exifTool->GetValue('DateTime','XMP-tiff');
    $capture_date =~ s/(\d{4}).(\d{2}).(\d{2}).(\d{2}).(\d{2}).(\d{2})(.*)/$1-$2-$3T$4:$5:$6$7/; # fix separator
    if(not defined $capture_date or !$capture_date) {
        $self->set_error("BadField",file => "00000001.jp2",field=>"XMP-tiff:DateTime",detail=>"Couldn't get capture time with ExifTool");
    } else {

        my $eventcode = 'capture';
        my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
        $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_date);
        $eventconfig->{'executor'} = 'ucm';
        $eventconfig->{'executor_type'} = 'HathiTrust Institution ID';
        $eventconfig->{'date'} = $capture_date; 
        my $event = $self->add_premis_event($eventconfig);
    }
}

sub _add_dmdsecs {
    my $self = shift;
    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $preingest_directory = $volume->get_preingest_directory();
    $self->_add_marc_from_file("$preingest_directory/marc.xml");


}

1;
