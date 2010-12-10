package HTFeed::PackageType::MDLContoneComposite;
use HTFeed::PackageType;
use HTFeed::VolumeValidator;
use HTFeed::PackageType::MDLContoneComposite::METS;
use HTFeed::Stage::Handle;
use HTFeed::Stage::Pack;
use HTFeed::Stage::Collate;
use base qw(HTFeed::PackageType::MDLContone);
use strict;

our $identifier = 'mdlcontone_composite';

our $config = {
    %{$HTFeed::PackageType::MDLContone::config},
    
    # Regular expression that distinguishes valid files in the file package
    # HTML OCR is valid for the package type but only expected/required for UC1
    valid_file_pattern => qr/^( 
		\w{3}\d{5}\w?\.(jp2|tif) |
		mdl\.\w+\.\w{3}\d{5}\w?-all\.(xml) |
		\w{3}\d{5}\w?\.(txt)
		$)/x,

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
	    file_pattern => qr/\.(jp2|tif)$/,
	    required => 1,
	    content => 1,
	    jhove => 1,
	    utf8 => 0
	},
	ocr => { 
	    prefix => 'OCR',
	    use => 'ocr',
	    file_pattern => qr/\.(txt)$/,
	    required => 0,
	    content => 1,
	    jhove => 0,
	    utf8 => 1
	},
    },

    source_mets_file => qr/^mdl\.\w+\.\w{3}\d{5}\w?-all\.xml$/,

    # Don't validate consistency for MDL Contone composite images -- there will not
    # always be an OCR image for every page image and seq numbers need not be sequential.
    validation_run_stages => [
        qw(validate_file_names
          validate_filegroups_nonempty
          validate_checksums
          validate_utf8
          validate_metadata)
    ],

    # The list of stages to run to successfully ingest a volume.
    stages_to_run => [qw(
        HTFeed::VolumeValidator
        HTFeed::Stage::Pack
        HTFeed::PackageType::MDLContoneComposite::METS
        HTFeed::Stage::Handle
        HTFeed::Stage::Collate
	)],

    module_validators => {
        'jp2'  => 'HTFeed::ModuleValidator::JPEG2000_hul',
	'tif' => 'HTFeed::ModuleValidator::TIFF_hul'
    },

    uncompressed_extensions => ['jp2','tif'],

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
