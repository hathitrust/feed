package HTFeed::PackageType::Feed;

use HTFeed::PackageType;
use base qw(HTFeed::PackageType);
use strict;

use HTFeed::XPathValidator qw(:closures);

our $identifier = 'feed';

our $config = {
    %{$HTFeed::PackageType::config},
    description => 'HTFeed-prepared material with source METS',

    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
    \S+.(xml) |
    \d{8}.(jp2|txt)$
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
            prefix       => 'IMG',
            use          => 'image',
            file_pattern => qr/^\d{8}.(jp2)$/,
            required     => 1,
            sequence     => 1,
            content      => 1,
            jhove        => 1,
            utf8         => 0
        },
        ocr => {
            prefix       => 'OCR',
            use          => 'ocr',
            file_pattern => qr/^\d{8}.(txt)$/,
            required     => 1,
            sequence     => 1,
            content      => 1,
            jhove        => 0,
            utf8         => 1
        },
    },

    source_mets_file => qr/^\S+.xml$/,

    # The list of stages to run to successfully ingest a volume.
    # The list of stages to run to successfully ingest a volume
    stage_map => {
        ready             => 'HTFeed::PackageType::Feed::Unpack',
        unpacked          => 'HTFeed::VolumeValidator',
        validated         => 'HTFeed::Stage::Pack',
        packed            => 'HTFeed::METS',
        metsed            => 'HTFeed::Stage::Handle',
        handled           => 'HTFeed::Stage::Collate',
    },

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
        'premis_migration', # optional
    ],

    # Validation 
    validation => {
      'HTFeed::ModuleValidator::JPEG2000_hul' => {
        'layers' => v_eq( 'codingStyleDefault', 'layers', '8' ),
      }
    },

    SIP_filename_pattern => '%s.zip'

};

__END__

=pod

This is the package type configuration file for ingesting SIPs created with feed into HathiTrust.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('yale');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=cut
