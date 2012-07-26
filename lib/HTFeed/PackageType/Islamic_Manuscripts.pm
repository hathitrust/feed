package HTFeed::PackageType::Islamic_Manuscripts;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MPub);

our $identifier = 'islamic_manuscripts';

our $config = {
    %{$HTFeed::PackageType::MPub::config},
    description => 'DCU-digitized Islamic Manuscripts',
    capture_agent => 'Digital Conversion Unit',
    
    # Regular expression that distinguishes valid files in the file package
	# jp2 only; no OCR
    valid_file_pattern => qr/^( 
		checksum\.md5 |
		pageview\.dat |
		\w+\.(xml) |
		\d{8}.(jp2)
		)/x,

	# A set of regular expressions mapping files to the filegroups they belong in
    filegroups => {
		image => {
	   		prefix => 'IMG',
	   		use => 'image',
	   		file_pattern => qr/\d{8}\.(jp2)$/,
	   		required => 1,
	   		content => 1,
	   		jhove => 1,
	   		utf8 => 0
		},
    },

	# no checksums
    validation_run_stages => [
        qw(validate_file_names
          validate_filegroups_nonempty
          validate_consistency
          validate_utf8
          validate_metadata)
    ],

    # The HTFeed::ModuleValidator subclass to use for validating
    # files with the given extensions
    module_validators => {
        'jp2'  => 'HTFeed::ModuleValidator::JPEG2000_hul',
    },


    # filename extensions not to compress in zip file
    uncompressed_extensions => ['jp2'],
    
};

__END__

=pod

This is the package type configuration file for MPub materials (Islamic MSS)

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
