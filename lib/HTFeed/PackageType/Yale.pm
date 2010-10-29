package HTFeed::PackageType::Yale;
use HTFeed::PackageType;
use base qw(HTFeed::PackageType);
use strict;

our $identifier = 'yale';

our $config = {
    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
		Yale_\w+\.(xml) |
		39002\d{9}_\d{6}.(xml|jp2|txt)
		)/x,

    # A set of regular expressions mapping files to the filegroups they belong
    # in
    filegroup_patterns => {
	image => qr/\.(jp2)$/,
	ocr => qr/\.txt$/,
	hocr => qr/\.xml$/
    },

    # A list of filegroups for which there must be a file for each page.
    required_filegroups => [qw(image hocr ocr)],

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 0,

    # The list of stages to run to successfully ingest a volume.
    stages_to_run => [qw(
        HTFeed::VolumeValidator
        HTFeed::PackageType::Yale::METS
        HTFeed::Handle
        HTFeed::Zip
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
