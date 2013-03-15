package HTFeed::PackageType::Kirtas;

use HTFeed::PackageType;
use base qw(HTFeed::PackageType);
use strict;

use HTFeed::XPathValidator qw(:closures);

our $identifier = 'kirtas';

our $config = {
    %{$HTFeed::PackageType::config},
    description => 'Kirtas-digitized book material',

    # Kirtas volumes will be cached on disk
    volume_module => 'HTFeed::PackageType::Kirtas::Volume',

    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
    Kirtas_\w+\.(xml) |
    \w+.(xml|jp2|tif|txt)$
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
            file_pattern => qr/\w+_\d+.(jp2|tif)$/,
            required     => 1,
            content      => 1,
            jhove        => 1,
            utf8         => 0
        },
        ocr => {
            prefix       => 'OCR',
            use          => 'ocr',
            file_pattern => qr/\w+_\d+.txt$/,
            required     => 1,
            content      => 1,
            jhove        => 0,
            utf8         => 1
        },
        hocr => {
            prefix       => 'XML',
            use          => 'coordOCR',
            file_pattern => qr/\w+_\d+.xml$/,
            required     => 1,
            content      => 1,
            jhove        => 0,
            utf8         => 1
        }
    },

    source_mets_file => qr/^Kirtas_\w+\.xml$/,

    # The list of stages to run to successfully ingest a volume.
    stage_map => {
        ready             => 'HTFeed::PackageType::Kirtas::Unpack',
        unpacked          => 'HTFeed::PackageType::Kirtas::VerifyManifest',
        manifest_verified => 'HTFeed::PackageType::Kirtas::ExtractOCR',
        ocr_extracted     => 'HTFeed::PackageType::Kirtas::ImageRemediate',
        images_remediated => 'HTFeed::PackageType::Kirtas::SourceMETS',
        src_metsed        => 'HTFeed::VolumeValidator',
        validated         => 'HTFeed::Stage::Pack',
        packed            => 'HTFeed::METS',
        metsed            => 'HTFeed::Stage::Handle',
        handled           => 'HTFeed::Stage::Collate',
    },


    # Validation overrides
    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            'camera'               => undef,
            'decomposition_levels' => v_between(
                'codingStyleDefault', 'decompositionLevels', '2', '32'
            ),
        },
    },

    # What PREMIS events to include in the source METS file
    source_premis_events => [

        # capture - included manually
        'source_md5_fixity',
        'image_header_modification',
        'ocr_normalize',
        'source_mets_creation',
        'page_md5_create',
        'mets_validation',
    ],

     # What PREMIS event types  to extract from the source METS and include in the HT METS
    source_premis_events_extract => [
        'capture',       
        'image_header_modification',
        'ocr_normalize', 
        'source_mets_creation',
        'page_md5_create',
    ],

    # What PREMIS events to include (by internal PREMIS identifier,
    # configured in config.yaml)
    premis_events => [
        'page_md5_fixity',
        'package_validation',
        'page_feature_mapping',
        'zip_compression',
        'zip_md5_create',
        'ingestion',
        'premis_migration', # optional
    ],

    # Overrides for the basic PREMIS event configuration
    premis_overrides => {
        'ocr_normalize' =>
          { detail => 'Extraction of plain-text OCR from ALTO XML', },
    },

    SIP_filename_pattern => '%s.zip',

    use_preingest => 1,


};

__END__

=pod

This is the package type configuration file for Kirtas.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('kirtas');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010-2012 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
