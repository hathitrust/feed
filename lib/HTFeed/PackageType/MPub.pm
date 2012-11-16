package HTFeed::PackageType::MPub;

use warnings;
use strict;
use base qw(HTFeed::PackageType);

#base case for MPub DCU

our $identifier = 'mpub';

our $config = {
    %{$HTFeed::PackageType::config},
    description => 'Mpublishing/DCU digitized material',
    volume_module => 'HTFeed::PackageType::MPub::Volume',
    
    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^(
		checksum\.md5 |
		pageview\.dat | 
		\w+\.(xml) |
		\w+\.(pdf) |
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
		pdf => {
            prefix => 'PDF',
            use => 'pdf',
            file_pattern => qr/\d{8}\.pdf$/,
            required => 0,
            content => 1,
            jhove => 0,
            utf8 => 0,
            # set to 0 to omit filegroup from structmap
            # (there is not a PDF file for every page, so including it in the
            # physical structmap wouldn't make much sense.)
            structmap => 0
        },
    },

    # The file containing the checksums for each data file
    checksum_file => "checksum.md5",

    # What stage to run given the current state.
    stage_map => {
        ready		=> 'HTFeed::PackageType::MPub::Fetch',
        fetched		=> 'HTFeed::VolumeValidator',
		validated	=> 'HTFeed::Stage::Pack',
		packed		=> 'HTFeed::PackageType::MPub::METS',
        metsed		=> 'HTFeed::Stage::Handle',
        handled		=> 'HTFeed::Stage::Collate',

        needs_uplift => 'HTFeed::Stage::RepositoryUnpack',
        uplift_unpacked => 'HTFeed::Stage::ReMETS'
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
	'ingestion',
	'premis_migration',
    ],


};

__END__

=pod

This is the package type configuration file for base case MPub / DCU materials

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
