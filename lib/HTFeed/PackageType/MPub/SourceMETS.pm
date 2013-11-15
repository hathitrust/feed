package HTFeed::PackageType::MPub::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::XMLNamespaces qw(:namespaces :schemas);
use HTFeed::Stage::Download;
use base qw(HTFeed::SourceMETS);
use POSIX qw(strftime);
use Image::ExifTool;

sub new {
    my $class  = shift;

    my $self = $class->SUPER::new( @_, );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    $self->{outfile} = "$stage_path/$pt_objid.xml";
    $self->{pagedata} = sub { $volume->get_srcmets_page_data(@_); };

    return $self;
}

sub _add_capture_event {

    my $self = shift;
    my $volume = $self->{volume};
    my $capture_time = $self->_get_capture_time();

    {
        # FIXME: use this capture agent instead of MiU... need to use controlled vocabulary (FUTURE)
        my $capture_agent = $volume->get_nspkg()->get('capture_agent');
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

sub _add_dmdsecs {
    my $self = shift;
    my $volume = $self->{volume};
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my $staging_directory = $volume->get_staging_directory();

    my $download = new HTFeed::Stage::Download(volume => $volume);
    # handle marcxml - just get it from aleph
    $self->set_error("MissingField",detail => "Can't get MARC-XML for non-MDP items from Aleph") if $namespace ne 'mdp';
    $download->download(url => "http://mirlyn-aleph.lib.umich.edu/cgi-bin/bc2meta?id=$objid&schema=marcxml&type=bc&idtag=955", 
            path => $staging_directory, filename => "marc.xml");

    $self->_add_marc_from_file("$staging_directory/marc.xml");

}

1;
