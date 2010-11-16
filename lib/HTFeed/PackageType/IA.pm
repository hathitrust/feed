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
		\d{8}.(xml|jp2|txt)
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

    # download to disk (as opposed to ram) if true
    download_to_disk => 0,
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