package HTFeed::PackageType::MDLContone_Composite;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MDLContone);

our $identifier = 'mdlcontone_composite';

our $config = {
    %{$HTFeed::PackageType::MDLContone::config},

    description => 'Minnesota Digital Library images- composite objects',

    # Regular expression that distinguishes valid files in the file package
    # HTML OCR is valid for the package type but only expected/required for UC1
    valid_file_pattern => qr/^( 
    \w+\d+\w?\.(jp2|tif) |
    mdl\.\w+\.\w+\d+\w?-all\.(xml) |
    \w+\d+\w?\.(txt)
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
            sequence => 1,
            content => 1,
            jhove => 1,
            utf8 => 0
        },
        ocr => { 
            prefix => 'OCR',
            use => 'ocr',
            file_pattern => qr/\.(txt)$/,
            required => 0,
            sequence => 1,
            content => 1,
            jhove => 0,
            utf8 => 1
        },
    },

    source_mets_file => qr/^mdl\.\w+\.\w+\d+\w?-all\.xml$/,

    # Don't validate consistency for MDL Contone composite images -- there will not
    # always be an OCR image for every page image and seq numbers need not be sequential.
    validation_run_stages => [
    qw(validate_file_names
    validate_filegroups_nonempty
    validate_checksums
    validate_utf8
    validate_metadata
    validate_digitizer)
    ],

    # what stage to run given the current state
    stage_map => {
        ready      => 'HTFeed::PackageType::MDLContone::Unpack',
        unpacked   => 'HTFeed::VolumeValidator',
        validated  => 'HTFeed::Stage::Pack',
        packed     => 'HTFeed::PackageType::MDLContone::Composite::METS',
        metsed     => 'HTFeed::Stage::Handle',
        handled    => 'HTFeed::Stage::Collate',

        needs_uplift => 'HTFeed::Stage::RepositoryUnpack',
        uplift_unpacked => 'HTFeed::Stage::ReMETS'
    },

    module_validators => {
        'jp2'  => 'HTFeed::ModuleValidator::JPEG2000_hul',
        'tif' => 'HTFeed::ModuleValidator::TIFF_hul'
    },

    uncompressed_extensions => ['jp2','tif'],

};

__END__

=pod

This is the package type configuration file for composite Minnesota Digital Library images 
with optional OCR.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('mdlcontone_composite');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
