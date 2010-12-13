package HTFeed::PackageType::Yale;
use HTFeed::PackageType;
use base qw(HTFeed::PackageType);
use strict;

use HTFeed::VolumeValidator;
##TODO: commented out to not break compile
#use HTFeed::PackageType::Yale::METS;
use HTFeed::Stage::Handle;
use HTFeed::Stage::Pack;
use HTFeed::Stage::Collate;
use HTFeed::PackageType::Yale::Volume;
use HTFeed::PackageType::Yale::Unpack;
use HTFeed::PackageType::Yale::VerifyManifest;
use HTFeed::PackageType::Yale::ExtractOCR;
use HTFeed::PackageType::Yale::ImageRemediate;
use HTFeed::PackageType::Yale::SourceMETS;

use HTFeed::XPathValidator qw(:closures);

our $identifier = 'yale';

our $config = {

    # Yale volumes will be cached on disk
    volume_module => 'HTFeed::PackageType::Yale::Volume',

    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
		Yale_\w+\.(xml) |
		39002\d{9}_\d{6}\.(xml|jp2|txt)$
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
            file_pattern => qr/39002\d{9}_\d{6}\.(jp2)$/,
            required     => 1,
            content      => 1,
            jhove        => 1,
            utf8         => 0
        },
        ocr => {
            prefix       => 'OCR',
            use          => 'ocr',
            file_pattern => qr/39002\d{9}_\d{6}\.txt$/,
            required     => 1,
            content      => 1,
            jhove        => 0,
            utf8         => 1
        },
        hocr => {
            prefix       => 'XML',
            use          => 'coordOCR',
            file_pattern => qr/39002\d{9}_\d{6}\.xml$/,
            required     => 1,
            content      => 1,
            jhove        => 0,
            utf8         => 1
        }
    },

    checksum_file    => 0,
    source_mets_file => qr/^Yale_\w+\.xml$/,

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 0,

    # The list of stages to run to successfully ingest a volume.
    # The list of stages to run to successfully ingest a volume
    stage_map => {
        ready       => 'HTFeed::PackageType::Yale::Unpack',
        unpacked    => 'HTFeed::PackageType::Yale::VerifyManifest',
        manifest_verified => 'HTFeed::PackageType::Yale::ExtractOCR',
        ocr_extracted =>'HTFeed::PackageType::Yale::ImageRemediate',
        images_remediated => 'HTFeed::PackageType::Yale::SourceMETS',
        src_metsed  => 'HTFeed::VolumeValidator',
        validated   => 'HTFeed::Stage::Pack',
        packed      => 'HTFeed::METS',
        metsed      => 'HTFeed::Stage::Handle',
        handled     => 'HTFeed::Stage::Collate',
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
        'jp2' => 'HTFeed::ModuleValidator::JPEG2000_hul',
        'tif' => 'HTFeed::ModuleValidator::TIFF_hul',
    },

    # Validation overrides
    validation => {
	'HTFeed::ModuleValidator::JPEG2000_hul' => {
	    'camera' => undef,
	    'decomposition_levels' => v_eq( 'codingStyleDefault', 'decompositionLevels', '3' ),
	},
    },

    validation_run_stages => [
	    qw(validate_file_names          
	    validate_filegroups_nonempty 
	    validate_consistency         
	    validate_checksums           
	    validate_utf8                
	    validate_metadata)
    ],

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

 # What PREMIS events to extract from the source METS and include in the HT METS
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
    ],

    # Overrides for the basic PREMIS event configuration
    premis_overrides => {
        'ocr_normalize' =>
          { detail => 'Extraction of plain-text OCR from ALTO XML', }
    },

    # File extensions not to compress
    uncompressed_extensions => ['jp2'],

};

__END__

=pod

This is the package type configuration file for Yale.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('yale');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
