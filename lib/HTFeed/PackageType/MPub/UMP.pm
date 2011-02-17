package HTFeed::PackageType::UMP;

use strict;
use warnings;
use base qw(HTFeed::PackageType);
use HTFeed::PackageType::MPub;
use HTFeed::VolumeValidator;
use HTFeed::Stage::Collate;
use HTFeed::Stage::Pack;
use HTFeed::Stage::Handle;

#base case (for DigOnDemand & Faculty Reprints)

our $identifier = 'ump';

our $config = {

    volume_module => 'HTFeed::Volume',
    
    # Regular expression that distinguishes valid files in the file package
    # Same as MPub, plus PDF
		 valid_file_pattern => qr/^( 
        checksum\.md5 |
        \w+\.(xml) |
		\w+\.(pdf) |
        \d{8}.(html|jp2|tif|txt)
        )/x,

	# A set of regular expressions mapping files to the filegroups they belong in
    filegroups => {
		image => {
	    	prefix => 'IMG',
	    	use => 'image',
	    	file_pattern => qr/\d{8}\.(jp2 |tif)$/,
	    	required => 1,
	    	content => 1,
	    	jhove => 1,
	    	utf8 => 0
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
		HTFeed::PackageType::MPub::Notify
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

This is the package type configuration file for MPub (UM Press).

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('ump');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
