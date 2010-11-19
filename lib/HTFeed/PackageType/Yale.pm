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

our $identifier = 'yale';

our $config = {
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
    # validate: set to 1 if some kind of validation will be performed on this filegroup
    # jhove: set to 1 if output from JHOVE will be used in validation
    # utf8: set to 1 if files should be verified to be valid UTF-8
    filegroups => {
	image => { 
	    prefix => 'IMG',
	    use => 'image',
	    file_pattern => qr/39002\d{9}_\d{6}\.(jp2)$/,
	    required => 1,
	    validate => 1,
	    jhove => 1,
	    utf8 => 0
	},
	ocr => { 
	    prefix => 'OCR',
	    use => 'ocr',
	    file_pattern => qr/39002\d{9}_\d{6}\.txt$/,
	    required => 1,
	    validate => 1,
	    jhove => 0,
	    utf8 => 1
	},
	hocr => { 
	    prefix => 'XML',
	    use => 'coordOCR',
	    file_pattern => qr/39002\d{9}_\d{6}\.xml$/,
	    required => 1,
	    validate => 1,
	    jhove => 0,
	    utf8 => 1
	}
    },

    source_mets_file => qr/^Yale_\w+\.xml$/,

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 0,

    # The list of stages to run to successfully ingest a volume.
    stages_to_run => [qw(
        HTFeed::VolumeValidator
        HTFeed::PackageType::Yale::METS
        HTFeed::Stage::Handle
        HTFeed::Stage::Pack
        HTFeed::Collate
	)],

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
    },

    # What PREMIS events to extract from the source METS and include
    source_premis_events => [
	'capture'
    ],

    # What PREMIS events to include (by internal PREMIS identifier, 
    # configured in config.yaml)
    premis_events => [
	'page_md5_fixity',
	'preingest',
	'page_md5_create',
	'package_validation',
	'page_feature_mapping',
#	'zip_compression',
	'zip_md5_create',
#	'ht_mets_creation',
	'ingestion',
    ],

    # Overrides for the basic PREMIS event configuration
    premis_overrides => {
	'ocr_normalize' => {
	    description => 'Extraction of plain-text OCR from ALTO XML',
	}
    }
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