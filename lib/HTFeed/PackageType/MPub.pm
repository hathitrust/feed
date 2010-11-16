package HTFeed::PackageType::MPub;
use HTFeed::PackageType;
use base qw(HTFeed::PackageType);
use strict;

##TODO: commented out to not break compile
#use HTFeed::PackageType::MPub::Fetch;
use HTFeed::VolumeValidator;
##TODO: commented out to not break compile
#use HTFeed::PackageType::MPub::METS;
use HTFeed::Stage::Pack;
use HTFeed::Stage::Collate;
use HTFeed::Stage::Handle;

########
## TODO: this was copied from Google.pm, lots of it is wrong
########

our $identifier = 'mpub';

our $config = {
    volume_module => 'HTFeed::Volume',
    
    # Regular expression that distinguishes valid files in the file package
    # HTML OCR is valid for the package type but only expected/required for UC1
    valid_file_pattern => qr/^( 
		checksum\.md5 |
		\w+\.(xml) |
		\d{8}.(html|jp2|tif|txt)
		)/x,

    # A set of regular expressions mapping files to the filegroups they belong
    # in
    filegroup_patterns => {
	image => qr/\.(jp2|tif)$/,
	ocr => qr/\.txt$/,
    },

    # A list of filegroups for which there must be a file for each page.
    required_filegroups => [qw(image txt)],

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 0,

    # The list of stages to run to successfully ingest a volume.
    stages_to_run => [qw(
        HTFeed::PackageType::MPub::Fetch
        HTFeed::VolumeValidator
        HTFeed::PackageType::MPub::METS
        HTFeed::Stage::Pack
        HTFeed::Stage::Collate
        HTFeed::Stage::Handle
	)],

    # The list of filegroups that contain files that will be validated
    # by JHOVE
    metadata_filegroups => [qw(image)],

    # The list of filegroups that contain files that should be validated
    # to use valid UTF-8
    utf8_filegroups => [qw(ocr)],

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
    'capture',
    'process',
    'analyze',
    'audit',
    'rubbish',
    ],

    # What PREMIS events to include (by internal PREMIS identifier, 
    # configured in config.yaml)
    premis_events => [
	'decryption',
	'page_md5_fixity',
	'page_md5_create',
	'package_validation',
	'zip_compression',
	'zip_md5_create',
#	'ht_mets_creation',
	'ingestion',
    ],

    # Overrides for the basic PREMIS event configuration
    premis_overrides => {
    },

    # filename extensions not to compress in zip file
    uncompressed_extensions => ['tif','jp2'],
    
};

__END__

=pod

This is the package type configuration file for Google / GRIN.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('google');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
