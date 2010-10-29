package HTFeed::PackageType::IA;

use warnings;
use strict;

use base qw(HTFeed::PackageType);
use HTFeed::PackageType::IA::Volume;

our $identifier = 'ia';

our $config = {
    volume_module => 'HTFeed::PackageType::IA::Volume',
    
    # Regular expression that distinguishes valid files in the file package
    # HTML OCR is valid for the package type but only expected/required for UC1
    valid_file_pattern => qr/^( 
		checksum\.md5 |
		\w+\.(xml) |
		\d{8}.(html|jp2|tif|txt)
		)/x,

    required_filegroups => [qw(image ocr)],

    filegroup_patterns => {
	    image => qr/\.(jp2|tif)$/,
	    ocr => qr/\.txt$/,
	    hocr => qr/\.html$/
    },

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 0,

    stages_to_run => [qw(
        HTFeed::PackageType::IA::Download
        HTFeed::PackageType::IA::Unpack
        HTFeed::PackageType::IngestTransform
        HTFeed::VolumeValidator
        HTFeed::PackageType::IA::METS
        HTFeed::Handle
        HTFeed::Zip
        HTFeed::Collate
	)],

    metadata_filegroups => [qw(image)],

    utf8_filegroups => [qw(ocr hocr)],

    module_validators => {
        'jp2'  => 'HTFeed::ModuleValidator::JPEG2000_hul',
        'tif'  => 'HTFeed::ModuleValidator::TIFF_hul',
    },

    validation => {
    },
    
    core_package_items => [qw(%s_jp2.zip %s_djvu.xml %s_meta.xml %s_scandata.xml %s_marc.xml)],
    non_core_package_items => [qw(%s_files.xml %s_scanfactors.xml)],
        
};

__END__

=pod

This is the package type configuration file for Internet Archive / IA.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('ia');

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
