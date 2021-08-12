package HTFeed::PackageType::MDLContone;

use warnings;
use strict;
use base qw(HTFeed::PackageType);

use HTFeed::XPathValidator qw(:closures);

our $identifier = 'mdlcontone';

our $config = {
    %{$HTFeed::PackageType::config},
    description => 'Minnesota Digital Library contone images',
    volume_module => 'HTFeed::Volume',

    # Regular expression that distinguishes valid files in the file package
    # HTML OCR is valid for the package type but only expected/required for UC1
    valid_file_pattern => qr/^( 
    \w+\d+\w?\.(jp2) |
    mdl\.\w+\.\w+\d+\w?\.(xml) |
    $)/x,

    # Configuration for each filegroup. 
    # prefix: the prefix to use on file IDs in the METS for files in this filegruop
    # use: the 'use' attribute on the file group in the METS
    # file_pattern: a regular expression to determine if a file is in this filegroup
    # required: set to 1 if a file from this filegroup is required for each page 
    # content: set to 1 if file should be included in zip file
    # jhove: set to 1 if output from JHOVE will be used in validation
    # utf8: set to 1 if files should be verified to be valid UTF-8
    filegroups => {
        image => { 
            prefix => 'IMG',
            use => 'image',
            file_pattern => qr/\.(jp2)$/,
            required => 1,
            sequence     => 1,
            content => 1,
            jhove => 1,
            utf8 => 0
        },
    },

    source_mets_file => qr/^mdl\.\w+\.\w+\d+\w?\.xml$/,

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 1,

    # Don't validate consistency for MDL Contone composite images -- there is only one
    # image, so no sequence numbers..
    validation_run_stages => [
    qw(validate_file_names
    validate_filegroups_nonempty
    validate_checksums
    validate_utf8
    validate_metadata
    validate_digitizer)
    ],

    # what stage to run given the current state
    stage_map => {
        ready      => 'HTFeed::PackageType::MDLContone::Unpack',
        unpacked   => 'HTFeed::PackageType::MDLContone::VolumeValidator',
        validated  => 'HTFeed::Stage::Pack',
        packed     => 'HTFeed::PackageType::MDLContone::METS',
        metsed     => 'HTFeed::Stage::Handle',
        handled    => 'HTFeed::Stage::Collate',

        needs_uplift => 'HTFeed::Stage::RepositoryUnpack',
        uplift_unpacked => 'HTFeed::Stage::ReMETS'
    },

    # Validation overrides
    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            'layers' => v_eq( 'codingStyleDefault', 'layers', '8' ),
            'transformation' => v_eq('codingStyleDefault','transformation','1'),
            'camera' => undef,
            'resolution'      => v_and(
                v_ge( 'xmp', 'xRes', 300 ), # should work even though resolution is specified as NNN/1
                v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
            ),
            'decomposition_levels' => v_eq( 'codingStyleDefault', 'decompositionLevels', '2' ),
        },

        'HTFeed::ModuleValidator::TIFF_hul' => {
            'resolution' =>
            v_and( v_in( 'mix', 'xRes', ['300','400','500','600'] ), v_in('mix', 'yRes', ['300','400','500','600'] ) ),
            'camera' => undef,
        }
    },

    # What PREMIS events to extract from the source METS and include
    source_premis_events_extract => [
    'capture',
    'image_compression',
    'image_header_modification',
    'page_md5_create',
    'source_mets_creation'
    ],

    # What PREMIS events to include (by internal PREMIS identifier, 
    # configured in config.yaml)
    premis_events => [
    'page_md5_fixity',
    'package_validation',
    'zip_compression',
    'zip_md5_create',
    'ingestion',
    'premis_migration', #optional
    ],


    SIP_filename_pattern => '%s.tar.gz',



};

__END__

=pod

This is the package type configuration file for Minnesota Digital Library images.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('mdlcontone');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu


=cut
