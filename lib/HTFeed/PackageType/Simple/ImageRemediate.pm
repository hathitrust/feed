package HTFeed::PackageType::Simple::ImageRemediate;

use strict;
use warnings;

use base qw(HTFeed::Stage::ImageRemediate);

use Carp;
use File::Basename qw(basename);
use File::Copy qw(move);
use HTFeed::Config qw(get_config);
use HTFeed::Stage::Fetch;
use List::Util qw(max min);
use Log::Log4perl qw(get_logger);
use POSIX qw(ceil);

my %tiff_field_map = (
    # will be automatically reformatted for IFD0:ModifyDate and XMP-tiff:DateTime
    capture_date  => 'DateTime',
    scanner_user  => 'IFD0:Artist',
    scanner_make  => 'IFD0:Make',
    scanner_model => 'IFD0:Model',
);

my %jpeg2000_field_map = (
    capture_date  => 'XMP-tiff:DateTime',
    scanner_user  => 'XMP-tiff:Artist',
    scanner_make  => 'XMP-tiff:Make',
    scanner_model => 'XMP-tiff:Model',
);

sub run {
    my $self          = shift;
    my $volume        = $self->{volume};
    my $preingest_dir = $volume->get_preingest_directory();
    my $staging_dir   = $volume->get_staging_directory();
    my $labels        = {packagetype => 'simple'};
    my $start_time    = $self->{job_metrics}->time;

    # decompress any lossless JPEG2000 images
    my @jp2 = glob("$preingest_dir/*.jp2");
    if (@jp2) {
        $self->expand_lossless_jpeg2000(
	    $volume,
	    $preingest_dir,
	    [map { basename($_) } @jp2]
	);
    }

    #remediate TIFFs
    my @tiffs = map { basename($_) } glob("$preingest_dir/*.tif");

    if (@tiffs) {
	# return extra fields to set that depend on the file
	my $headers_sub = sub {
	    my $file = shift;
	    my $force_fields = { 'IFD0:DocumentName' => join('/', $volume->get_objid(), $file) };
	    my $set_if_undefined = {};
	    while (my ($meta_yml_field, $tiff_field) = each(%tiff_field_map)) {
		$self->set_from_meta_yml($meta_yml_field, $set_if_undefined, $tiff_field);
	    }
	    # force override resolution if it is provided in meta.yml
	    $self->set_from_meta_yml('bitonal_resolution_dpi', $force_fields, 'Resolution');

	    return ($force_fields, $set_if_undefined, $file);
	};

	$self->remediate_tiffs(
	    $volume,
	    $preingest_dir,
	    \@tiffs,
	    $headers_sub
	)
    }

    # remediate JP2s
    foreach my $jp2_submitted (glob("$preingest_dir/*.jp2")) {
        my $jp2_fields  = $self->get_exiftool_fields($jp2_submitted);
        my $staging_dir = $volume->get_staging_directory();

        # there shouldn't be any JP2s for MOA material?
        my $force_fields     = { 'XMP-dc:source' => join('/', $volume->get_objid(), basename($jp2_submitted)) };
        my $set_if_undefined = {};
        my $jp2_remediated   = "$staging_dir/" . basename($jp2_submitted);

        while (my ($meta_yml_field, $jp2_field) = each(%jpeg2000_field_map)) {
            $self->set_from_meta_yml($meta_yml_field, $set_if_undefined, $jp2_field);
        }

        # force override resolution if it is provided in meta.yml
        $self->set_from_meta_yml('contone_resolution_dpi', $force_fields, 'Resolution');

        $self->remediate_image($jp2_submitted, $jp2_remediated, $force_fields, $set_if_undefined);
    }

    $volume->record_premis_event('image_header_modification');

    # remove newlines & move OCR, supplementary files
    my $fetch = HTFeed::Stage::Fetch->new(volume => $volume);
    foreach my $file (glob("$preingest_dir/[0-9]*[0-9].{txt,html,xml}")) {
        move($file, $staging_dir);
    }
    foreach my $file (glob("$preingest_dir/*.pdf")) {
        move($file, $staging_dir);
    }
    $fetch->fix_line_endings($staging_dir);

    my $page_count = $volume->get_page_count();
    my $end_time   = $self->{job_metrics}->time;
    my $delta_time = $end_time - $start_time;
    $self->{job_metrics}->add("ingest_imageremediate_seconds_total", $delta_time, $labels);
    $self->{job_metrics}->add("ingest_imageremediate_images_total", $page_count, $labels);
    $self->{job_metrics}->inc("ingest_imageremediate_items_total", $labels);

    $self->_set_done();
    return $self->succeeded();
}

sub set_from_meta_yml {
    my $self           = shift;
    my $meta_yml_key   = shift;
    my $field_output   = shift;
    my $metadata_field = shift;
    my $require        = shift || 0;
    my $metadata_value = $self->{volume}->get_meta($meta_yml_key);

    if ($require and not defined $metadata_value) {
        $self->set_error("MissingField", file => 'meta.yml', field => $meta_yml_key);
    }
    return if not defined $metadata_value;

    $field_output->{$metadata_field} = $metadata_value;
}

1;
