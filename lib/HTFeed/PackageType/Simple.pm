package HTFeed::PackageType::Simple;

use warnings;
use strict;
use base qw(HTFeed::PackageType);
use HTFeed::XPathValidator qw(:closures);

our $identifier = 'simple';

our $config = {

    %{$HTFeed::PackageType::config},
    description => 'Simple SIP format for cloud validator',

    volume_module => 'HTFeed::PackageType::Simple::Volume',


    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
    checksum\.md5 |
    meta\.yml |
    marc\.xml |
    \d{8}.(html|xml|jp2|tif|txt) |
    .*\.mets\.xml
    )/x,

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
            file_pattern => qr/\d{8}\.(jp2|tif)$/,
            required => 1,
            sequence => 1,
            content => 1,
            jhove => 1,
            utf8 => 0
        },
        # FIXME -- should configure at submission level
        ocr => { 
            prefix => 'TXT',
            use => 'ocr',
            file_pattern => qr/\d{8}\.txt$/,
            required => 0,
            sequence => 1,
            content => 1,
            jhove => 0,
            utf8 => 1
        },
        # shouldn't have both..
        hocr => { 
            prefix => 'HTML',
            use => 'coordOCR',
            file_pattern => qr/\d{8}\.html$/,
            required => 0,
            sequence => 1,
            content => 1,
            jhove => 0,
            utf8 => 1
        },
        xml_hocr => { 
            prefix => 'XML',
            use => 'coordOCR',
            file_pattern => qr/^\d{8}\.xml$/,
            required => 0,
            sequence => 1,
            content => 1,
            jhove => 0,
            utf8 => 1
        }
    },

    checksum_file => qr/checksum\.md5$/,

    # what stage to run given the current state
    stage_map => {
        ready             => 'HTFeed::PackageType::Simple::Unpack',
        unpacked     => 'HTFeed::PackageType::Simple::VerifyManifest',
        manifest_verified => 'HTFeed::PackageType::Simple::ImageRemediate',
        images_remediated => 'HTFeed::PackageType::Simple::SourceMETS',
        src_metsed        => 'HTFeed::VolumeValidator',
        validated  => 'HTFeed::Stage::Pack',
        packed     => 'HTFeed::PackageType::Simple::METS',
        metsed     => 'HTFeed::Stage::Handle',
        handled    => 'HTFeed::Stage::Collate',
    },


    # What PREMIS events to include in the source METS file
    source_premis_events => [
        # capture - included manually
        'page_md5_fixity',
        'image_header_modification',
        'image_compression', # optional
        'source_mets_creation',
        'page_md5_create',
        'mets_validation',
    ],

     # What PREMIS event types  to extract from the source METS and include in the HT METS
    source_premis_events_extract => [
        'capture',       
        'image_header_modification',
        'source_mets_creation',
        'page_md5_create',
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

    SIP_filename_pattern => '%s.zip',
#    SIP_filename_pattern => '',

    source_mets_file => '.*.mets.xml',

    checksum_file => 'checksum.md5',

    use_preingest => 1,

    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            'camera' => undef,
            # allow most common # of layers
          'layers' => v_in( 'codingStyleDefault', 'layers', ['1','6','8','25'] ),
          'decomposition_levels' => v_between( 'codingStyleDefault', 'decompositionLevels', '1', '32'),
          'resolution'      => v_and(
              v_ge( 'xmp', 'xRes', 300 ), # should work even though resolution is specified as NNN/1
              v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
          ),
        },
        'HTFeed::ModuleValidator::TIFF_hul' => {
            'camera' => undef,
            'resolution'      => HTFeed::ModuleValidator::TIFF_hul::v_resolution_ge(600)
        }
    }
};

__END__

=pod

This is the package type configuration file for the simple cloud validation format.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('simple');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=cut
