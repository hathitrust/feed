package HTFeed::PackageType::IA;

use warnings;
use strict;

use base qw(HTFeed::PackageType);
use HTFeed::PackageType::IA::Volume;

use HTFeed::VolumeValidator;
##TODO: commented out to not break compile
#use HTFeed::PackageType::IA::METS;
use HTFeed::Stage::Handle;
use HTFeed::Stage::Pack;
use HTFeed::Stage::Collate;

our $identifier = 'ia';

our $config = {
    volume_module => 'HTFeed::PackageType::IA::Volume',
    
    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
		IA_\w+\.(xml) |
		\d{8}\.(xml|jp2|txt)
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
	hocr => { 
	    prefix => 'XML',
	    use => 'coordOCR',
	    file_pattern => qr/\d{8}\.xml$/,
	    required => 1,
	    content => 1,
	    jhove => 0,
	    utf8 => 1
	}
    },

    checksum_file => 0, # no separate checksum file for IA
    source_mets_file => qr/^IA_\w+\.xml$/,

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 1,

    # The list of stages to run to successfully ingest a volume.
    stages_to_run => [qw(
        HTFeed::VolumeValidator
        HTFeed::PackageType::IA::METS
        HTFeed::Stage::Handle
        HTFeed::Stage::Pack
        HTFeed::Stage::Collate
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
};

__END__

=pod

This is the package type configuration file for Internet Archive.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('ia');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
