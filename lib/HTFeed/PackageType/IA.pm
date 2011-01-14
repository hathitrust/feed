package HTFeed::PackageType::IA;

use warnings;
use strict;

use base qw(HTFeed::PackageType);
use HTFeed::PackageType::IA::Volume;

use HTFeed::VolumeValidator;
##TODO: commented out to not break compile
#use HTFeed::PackageType::IA::METS;
use HTFeed::Stage::Handle;
use HTFeed::Stage::Pack;
use HTFeed::Stage::Collate;
use HTFeed::PackageType::IA::Download;
use HTFeed::PackageType::IA::VerifyManifest;
use HTFeed::PackageType::IA::Unpack;
use HTFeed::PackageType::IA::DeleteCheck;
use HTFeed::PackageType::IA::OCRSplit;
use HTFeed::PackageType::IA::ImageRemediate;
use HTFeed::PackageType::IA::SourceMETS;


our $identifier = 'ia';

our $config = {
    volume_module => 'HTFeed::PackageType::IA::Volume',

    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
    IA_ark\+=13960=\w+\.(xml) |
    \d{8}\.(xml|jp2|txt)
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
            content => 1,
            jhove => 1,
            utf8 => 0
        },
        ocr => { 
            prefix => 'OCR',
            use => 'ocr',
            file_pattern => qr/\d{8}\.txt$/,
            required => 0,
            content => 1,
            jhove => 0,
            utf8 => 1
        },
        hocr => { 
            prefix => 'XML',
            use => 'coordOCR',
            file_pattern => qr/\d{8}\.xml$/,
            required => 0,
            content => 1,
            jhove => 0,
            utf8 => 1
        }
    },

    # Which validation stages should be run on this content?
    validation_run_stages => [
    qw(validate_file_names          
    validate_filegroups_nonempty 
    validate_checksums
    validate_utf8                
    validate_metadata)
    ],

    # What PREMIS events to include in the source METS file
    source_premis_events => [
        # capture - included manually
        'package_inspection',
        'file_rename',
        'source_md5_fixity',
        'image_header_modification',
        'ocr_normalize',
        'page_md5_create',
        'source_mets_creation',
        'mets_validation',
    ],

    source_premis_events_extract => [
        'capture',
        'package_inspection',
        'file_rename',
        'image_header_modification',
        'ocr_normalize',
        'page_md5_create',
        'source_mets_creation',
    ],

    premis_events => [
        'page_md5_fixity',      'package_validation',
        'page_feature_mapping', 'zip_compression',
        'zip_md5_create',       'ingestion',
    ],

    # Overrides for the basic PREMIS event configuration
    premis_overrides => {
        'ocr_normalize' =>
          { detail => 'Splitting of IA XML OCR into one plain text OCR file and one XML file (with coordinates) per page', }
    },

    checksum_file => 0, # no separate checksum file for IA
    source_mets_file => qr/^IA_ark\+=13960=\w+\.xml$/,

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 1,

    # The list of stages to run to successfully ingest a volume.
    stage_map => {
        ready             => 'HTFeed::PackageType::IA::Download',
        downloaded        => 'HTFeed::PackageType::IA::VerifyManifest',
        manifest_verified => 'HTFeed::PackageType::IA::Unpack',
        unpacked          => 'HTFeed::PackageType::IA::DeleteCheck',
        delete_checked    => 'HTFeed::PackageType::IA::OCRSplit',
        ocr_extracted     => 'HTFeed::PackageType::IA::ImageRemediate',
        images_remediated => 'HTFeed::PackageType::IA::SourceMETS',
        src_metsed        => 'HTFeed::VolumeValidator',
        validated         => 'HTFeed::Stage::Pack',
        packed            => 'HTFeed::METS',
        metsed            => 'HTFeed::Stage::Handle',
        handled           => 'HTFeed::Stage::Collate',
    },

    # The list of filegroups that contain files that will be validated
    # by JHOVE
    metadata_filegroups => [qw(image)],

    # The list of filegroups that contain files that should be validated
    # to use valid UTF-8
    utf8_filegroups => [qw(ocr hocr)],

    # The HTFeed::ModuleValidator subclass to use for validating
    # files with the given extensions
    module_validators => {
        'jp2'  => 'HTFeed::ModuleValidator::JPEG2000_hul',
        'tif'  => 'HTFeed::ModuleValidator::TIFF_hul',
    },

    # Validation overrides
    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            'camera'               => undef,
        }
    },

    # Required items for download; %s will be replaced by IA ID
    core_package_items => [ 
    '%s_jp2.zip',
    '%s_djvu.xml',
    '%s_meta.xml',
    '%s_marc.xml'  ],

    # Optional items for download
    non_core_package_items => [ 
    '%s_files.xml',
    '%s_scanfactors.xml' ],

    uncompressed_extensions => [qw(tif jp2)],

};

__END__

=pod

This is the package type configuration file for Internet Archive.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('ia');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
