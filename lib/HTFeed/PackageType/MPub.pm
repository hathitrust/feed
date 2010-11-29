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
            required => 1,
            content => 1,
            jhove => 0,
            utf8 => 1
        },

    },

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

    # The file containing the checksums for each data file
    checksum_file => qr/^checksum.md5$/,


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
