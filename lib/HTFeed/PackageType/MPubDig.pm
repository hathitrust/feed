package HTFeed::PackageType::MPubDig;

use HTFeed::PackageType;
use base qw(HTFeed::PackageType);
use strict;

use HTFeed::PackageType::MPub::Fetch;
use HTFeed::VolumeValidator;
use HTFeed::Stage::Pack;
use HTFeed::Stage::Handle;
use HTFeed::Stage::Collate;

#base case for MPub DigOnDemand

our $identifier = 'DigOnDemand';

our $config = {
    volume_module => 'HTFeed::Volume',
    
    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
		checksum\.md5 |
		pageview\.dat |
		\w+\.(xml) |
		\d{8}.(html|jp2|tif|txt)
		)/x,

	# A set of regular expressions mapping files to the filegroups they belong in
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
            required => 1,
            content => 1,
            jhove => 0,
            utf8 => 1
        },
    },

    # The file containing the checksums for each data file
    checksum_file => qr/^checksum.md5$/,

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 0,

	validation_run_stages => [
    qw(validate_file_names 
    validate_filegroups_nonempty
    validate_consistency
    validate_checksums
    validate_utf8
    validate_metadata)
    ],

    # What stage to run given the current state.
    stage_map => {
        ready		=> 'HTFeed::PackageType::MPub::Fetch',
        fetched		=> 'HTFeed::VolumeValidator',
		validated	=> 'HTFeed::Stage::Pack',
        packed		=> 'HTFeed::Stage::Handle',
        handled		=> 'HTFeed::Stage::Collate',
	},

	# Filegroups that contain files that will be validated by JHOVE
	metadata_filegroups	=> [qw(image)],

	# Filegroups that contain files that should be validated to use UTF-8
	utf8_filegroups		=> [qw(ocr)],

    # The HTFeed::ModuleValidator subclass to use for validating
    # files with the given extensions
    module_validators => {
        'jp2'  => 'HTFeed::ModuleValidator::JPEG2000_hul',
        'tif'  => 'HTFeed::ModuleValidator::TIFF_hul',
    },

    # Validation overrides
    validation => {
    },

    # What PREMIS events to include (by internal PREMIS identifier, 
    # configured in config.yaml)
    # TODO: review/fix MPub PREMIS events
    premis_events => [
	'page_md5_fixity',
	'page_md5_create',
	'package_validation',
	'zip_compression',
	'zip_md5_create',
#	'ht_mets_creation',
	'ingestion',
    ],

    # filename extensions not to compress in zip file
    uncompressed_extensions => ['tif','jp2'],
    
};

__END__

=pod

This is the package type configuration file for base case MPub materials
Specifically DigOnDemand

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('mpub');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
