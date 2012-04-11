#!/usr/bin/perl

package HTFeed::PackageType::DLXS::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use base qw(HTFeed::SourceMETS);
use HTFeed::METS;
use Image::ExifTool;


sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

    );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    $self->{outfile} = "$stage_path/DLXS_" . $pt_objid . ".xml";
    $self->{pagedata} = sub { $volume->get_srcmets_page_data(@_); };

    return $self;
}

sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};
    my $premis = $self->{premis};
    
    # first try to get the capture date for the first image
    my $exifTool = new Image::ExifTool;
    $exifTool->ExtractInfo($volume->get_staging_directory() . "/00000001.tif");
    my $capture_date = $exifTool->GetValue('ModifyDate','IFD0');
    if(not defined $capture_date or !$capture_date) {
        $capture_date = $volume->get_loadcd_info()->{load_date};
    }
        
    $capture_date =~ s/(\d{4}).(\d{2}).(\d{2}).(\d{2}).(\d{2}).(\d{2})(.*)/$1-$2-$3T$4:$5:$6$7/; # fix separator

    my $eventcode = 'capture';
    my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
    $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_date);
    $eventconfig->{'executor'} = 'MiU';
    $eventconfig->{'executor_type'} = 'MARC21 Code';
    # FOR TESTING ONLY
    $eventconfig->{'date'} = $capture_date;
    my $event = $self->add_premis_event($eventconfig);
}


1;
