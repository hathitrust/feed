package HTFeed::PackageType::Simple::ImageRemediate;

use warnings;
use strict;
use base qw(HTFeed::Stage::ImageRemediate);
use List::Util qw(max min);
use POSIX qw(ceil);
use HTFeed::Config qw(get_config);
use HTFeed::Stage::Fetch;
use Log::Log4perl qw(get_logger);
use File::Basename qw(basename);
use File::Copy qw(move);
use Carp;

my %tiff_field_map = (
    # will be automatically reformatted for IFD0:ModifyDate and XMP-tiff:DateTime
    capture_date => 'DateTime', 
    scanner_user => 'IFD0:Artist',
    scanner_make => 'IFD0:Make',
    scanner_model => 'IFD0:Model',
);

my %jpeg2000_field_map = (
    capture_date => 'XMP-tiff:DateTime',
    scanner_user => 'XMP-tiff:Artist',
    scanner_make => 'XMP-tiff:Make',
    scanner_model => 'XMP-tiff:Model',
);

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $preingest_dir = $volume->get_preingest_directory();
    my $staging_dir = $volume->get_staging_directory();

    # decompress any lossless JPEG2000 images
#    $self->expand_lossless_jpeg2000($volume,$preingest_dir,[map { basename($_) } glob("$preingest_dir/*.jp2")]);

     #remediate TIFFs
    my @tiffs = map { basename($_) } glob("$preingest_dir/*.tif");
    $self->remediate_tiffs($volume,$preingest_dir,\@tiffs,

        # return extra fields to set that depend on the file
        sub {
            my $file = shift;

            my $force_fields = {'IFD0:DocumentName' => join('/',$volume->get_objid(),$file) };
            my $set_if_undefined = {};
            while(my ($meta_yml_field,$tiff_field) = each(%tiff_field_map)) {
                $self->set_from_meta_yml($meta_yml_field,$set_if_undefined,$tiff_field);
            }

            # force override resolution if it is provided in meta.yml
            $self->set_from_meta_yml('bitonal_resolution_dpi',$force_fields,'Resolution');

            return ( $force_fields, $set_if_undefined, $file);
        }
    ) if @tiffs;

    # remediate JP2s

    foreach my $jp2_submitted (glob("$preingest_dir/*.jp2"))
    {
        my $jp2_fields = $self->get_exiftool_fields($jp2_submitted);

        my $staging_dir = $volume->get_staging_directory();

        # there shouldn't be any JP2s for MOA material?
        my $force_fields = {'XMP-dc:source' => join('/',$volume->get_objid(),basename($jp2_submitted)) };
        my $set_if_undefined = {};
        my $jp2_remediated = "$staging_dir/" . basename($jp2_submitted);

        while(my ($meta_yml_field,$jp2_field) = each(%jpeg2000_field_map)) {
            $self->set_from_meta_yml($meta_yml_field,$set_if_undefined,$jp2_field);
        }

        # force override resolution if it is provided in meta.yml
        $self->set_from_meta_yml('contone_resolution_dpi',$force_fields,'Resolution');

        $self->remediate_image( $jp2_submitted, $jp2_remediated, $force_fields, $set_if_undefined );
    }

    $volume->record_premis_event('image_header_modification');

    # remove newlines & move OCR, supplementary files
    my $fetch = HTFeed::Stage::Fetch->new(volume => $volume);
    foreach my $file (glob("$preingest_dir/[0-9]*[0-9].{txt,html,xml,pdf}")) {
        move($file,$staging_dir);
    }
    $fetch->fix_line_endings($staging_dir);


    $self->_set_done();
    return $self->succeeded();

}

sub set_from_meta_yml {
    my $self = shift;
    my $meta_yml_key = shift;
    my $field_output = shift;
    my $metadata_field = shift;
    my $require = shift;

    $require = 0 if not defined $require;

    my $metadata_value = $self->{volume}->get_meta($meta_yml_key);

    if($require and not defined $metadata_value) {
        $self->set_error("MissingField",file => 'meta.yml',field=> $meta_yml_key);
    }

    return if not defined $metadata_value;

    $field_output->{$metadata_field} = $metadata_value;
}


1;

__END__
