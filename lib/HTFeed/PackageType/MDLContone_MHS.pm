package HTFeed::PackageType::MDLContone_MHS;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::PackageType::MDLContone);
use warnings;
use strict;

our $identifier = 'mdlcontone_mhs';

our $config = {
    %{$HTFeed::PackageType::MDLContone::config},
    description => 'Minnesota Historical Society images',
    volume_module => 'HTFeed::Volume',

    # Regular expression that distinguishes valid files in the file package
    # HTML OCR is valid for the package type but only expected/required for UC1
    valid_file_pattern => qr/^( 
    [a-z0-9-]+.(jp2) |
    mdl\.[a-z0-9.-]+.(xml) |
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
            prefix       => 'IMG',
            use          => 'image',
            file_pattern => qr/\.(jp2)$/,
            required     => 1,
            sequence     => 1,
            content      => 1,
            jhove        => 1,
            utf8         => 0
        },
    },

    source_mets_file => qr/^mdl\.[a-z0-9.-]+.xml$/,

    # The HTFeed::ModuleValidator subclass to use for validating
    # files with the given extensions
    module_validators => {
        'jp2' => 'HTFeed::ModuleValidator::JPEG2000_hul',
    },

    # what stage to run given the current state
    stage_map => {
        ready      => 'HTFeed::PackageType::MDLContone::Unpack',
        unpacked   => 'HTFeed::PackageType::MDLContone::VolumeValidator',
        validated  => 'HTFeed::Stage::Pack',
        packed     => 'HTFeed::PackageType::MDLContone::Composite::METS',
        metsed     => 'HTFeed::Stage::Handle',
        handled    => 'HTFeed::Stage::Collate',

        needs_uplift => 'HTFeed::Stage::RepositoryUnpack',
        uplift_unpacked => 'HTFeed::Stage::ReMETS'
    },


    # Validation overrides
    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            'layers' => v_eq( 'codingStyleDefault', 'layers', '8' ),
            'transformation' =>
              v_eq( 'codingStyleDefault', 'transformation', '1' ),
            'camera'     => undef,
            'resolution' => v_and(
                v_ge( 'xmp', 'xRes', '300' ),
                v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
            ),
            'decomposition_levels' =>
              v_eq( 'codingStyleDefault', 'decompositionLevels', '2' ),
        },

        'HTFeed::ModuleValidator::JPEG_hul' => {
            'resolution' => v_and(
                v_same( 'mix', 'xRes', 'mix', 'yRes'),
            ),
            'camera' => undef,
        }
    },

    # filename extensions not to compress in zip file
    uncompressed_extensions => [ 'jp2', 'jpg' ],

};

__END__

=pod

This is the package type configuration file for Minnesota Digital Library images
from the Minnesota Historical Society.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('mdlcontone_mhs');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=cut
