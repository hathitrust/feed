package HTFeed::PackageType::IA::ImageRemediate;

use strict;
use warnings;

use base qw(HTFeed::Stage::ImageRemediate);

use Carp;
use File::Basename qw(basename);
use Log::Log4perl qw(get_logger);
use POSIX qw(strftime);

sub run {
    my $self = shift;

    my $volume        = $self->{volume};
    my $preingest_dir = $volume->get_preingest_directory();
    my $stage_path    = $volume->get_staging_directory();
    my $objid         = $volume->get_objid();
    my $scandata_xpc  = $volume->get_scandata_xpc();
    my $resolution    = $volume->get_db_resolution();
    my $labels        = {packagetype => 'ia'};
    my $start_time    = $self->{job_metrics}->time;

    # Fall back to getting resolution from scandata or meta
    if (not defined $resolution or !$resolution) {
	$resolution = $scandata_xpc->findvalue("//scribe:bookData/scribe:dpi | //bookData/dpi")
    }
    if (not defined $resolution or !$resolution) {
	$resolution = $volume->get_meta_xpc()->findvalue("//ppi");
    }
    $resolution =~ s/ppi//;

    # decompress any lossless JPEG2000 images
    my @jp2 = glob("$preingest_dir/*.jp2");
    if(@jp2) {
        $self->expand_lossless_jpeg2000(
	    $volume,
	    $preingest_dir,
	    [map { basename($_) } @jp2]
	);
    }

    #remediate TIFFs (incl. expanded JPEG2000 images)
    my @tiffs = map { basename($_) } glob("$preingest_dir/*.tif");
    $self->remediate_tiffs(
	$volume,
	$preingest_dir,
	\@tiffs,

        # return extra fields to set that depend on the file
        sub {
            my $file = shift;

            my $set_if_undefined_fields = {};
            my $force_fields            = {'IFD0:DocumentName' => join('/',$volume->get_objid(),$file) };
            if (my $capture_time = $self->get_capture_time($file)) {
                $set_if_undefined_fields->{'XMP-tiff:DateTime'} = $capture_time;
            }
            $set_if_undefined_fields->{'Resolution'} = $resolution if defined $resolution and $resolution;

            return ($force_fields, $set_if_undefined_fields, $file);
        }
    ) if @tiffs;

    opendir(my $dirh, "$preingest_dir") or croak("Can't opendir $preingest_dir: $!");
    while (my $file = readdir($dirh)) {
        next unless $file =~ /(\d{4})\.jp2$/;

        my $seqnum         = $1;
        my $new_filename   = sprintf("%08d.jp2",$seqnum);
        my $jp2_submitted  = "$preingest_dir/$file";
        my $jp2_remediated = "$stage_path/$new_filename";

        my $set_always_fields = {
            'XMP-dc:source'   => "$objid/$new_filename",
            'XMP-tiff:Artist' => $volume->tiff_artist()
        };

        my $set_if_undefined_fields = {};

        if (my $capture_time = $self->get_capture_time($file)) {
            $set_if_undefined_fields->{'XMP-tiff:DateTime'} = $capture_time;
        }
        if (defined $resolution and $resolution) {
            $set_if_undefined_fields->{'Resolution'} = $resolution;
        }

        $self->remediate_image(
            $jp2_submitted,
	    $jp2_remediated,
            $set_always_fields,
	    $set_if_undefined_fields
        );

    }
    closedir($dirh);

    $volume->record_premis_event('image_header_modification');
    $volume->record_premis_event('file_rename');

    # Record metrics
    my $end_time   = $self->{job_metrics}->time;
    my $delta_time = $end_time - $start_time;
    my $page_count = $volume->get_page_count();
    $self->{job_metrics}->add("ingest_imageremediate_seconds_total", $delta_time, $labels);
    $self->{job_metrics}->add("ingest_imageremediate_images_total", $page_count, $labels);
    $self->{job_metrics}->inc("ingest_imageremediate_items_total", $labels);

    $self->_set_done();
    return $self->succeeded();
}

sub get_capture_time {
    my $self       = shift;
    my $image_file = shift;

    my $volume         = $self->{volume};
    my $xpc            = $volume->get_scandata_xpc();
    my $preingest_dir  = $volume->get_preingest_directory();
    my $gmtTimeStampRE = qr/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;

    # Get the time of creation from scandata.xml
    my $leafNum = int($image_file =~ /_(\d{4}).jp2/);
    # A couple places this might appear, and it might be with or without a namespace..
    my $gmtTimeStamp = $xpc->findvalue(
	qq(//scribe:pageData/scribe:page[\@leafNum='$leafNum']/scribe:gmtTimeStamp | //pageData/page[\@leafNum='$leafNum']/gmtTimeStamp)
    );
    # TODO: Start or end time stamp? Or do we want to get it from the file?
    if (not defined $gmtTimeStamp or $gmtTimeStamp eq '' or $gmtTimeStamp !~ $gmtTimeStampRE) {
        $gmtTimeStamp = $xpc->findvalue(
	    '//scribe:scanLog/scribe:scanEvent/scribe:endTimeStamp | //scanLog/scanEvent/endTimeStamp'
	);
    }

    if (not defined $gmtTimeStamp or $gmtTimeStamp eq '' or $gmtTimeStamp !~ $gmtTimeStampRE) {
        my $meta_xpc = $self->{volume}->get_meta_xpc();
        $gmtTimeStamp = $meta_xpc->findvalue('//scandate');
    }

    # use file time stamp if all else fails
    if (not defined $gmtTimeStamp or $gmtTimeStamp eq '' or $gmtTimeStamp !~ $gmtTimeStampRE) {
        $gmtTimeStamp = strftime("%Y%m%d%H%M%S",gmtime((stat("$preingest_dir/$image_file"))[9]));
    }

    # Format is YYYYMMDDHHmmss
    if (defined $gmtTimeStamp and $gmtTimeStamp =~ $gmtTimeStampRE) {
        return ("$1:$2:$3 $4:$5:$6+00:00");
    }
}

1;
