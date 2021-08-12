package HTFeed::PackageType::SingleImage;

use warnings;
use strict;
use base qw(HTFeed::PackageType);
use HTFeed::XPathValidator qw(:closures);


our $identifier = 'singleimage';

our $config = {

    %{$HTFeed::PackageType::config},
    description => 'Single images uploaded for validation',

    volume_module => 'HTFeed::Volume',

    # Regular expression that distinguishes valid files in the file package
    # HTML OCR is valid for the package type but only expected/required for UC1
    valid_file_pattern => qr/^( 
    \d{8}.(jp2|tif)
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
            sequence => 1,
            content => 1,
            jhove => 1,
            utf8 => 0
        },
    },


    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            # allow most common # of layers
          'layers' => v_in( 'codingStyleDefault', 'layers', ['1','8'] ),
          'resolution'      => v_and(
              v_ge( 'xmp', 'xRes', 300 ), # should work even though resolution is specified as NNN/1
              v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
          ),
        },
        'HTFeed::ModuleValidator::TIFF_hul' => {
            'resolution'      => HTFeed::ModuleValidator::TIFF_hul::v_resolution_ge(600)
        }
    },

    # regex that will never match
    source_mets_file => qr/(?!)/,

};

__END__

=pod

This is the package type configuration file for single images uploaded for validation.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('singleimage');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=cut
