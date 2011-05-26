package HTFeed::PackageType::UCM;

use HTFeed::PackageType;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::PackageType);
use strict;

our $identifier = 'ucm';

our $config = {
    %{$HTFeed::PackageType::config},
    description => 'Madrid-digitized book material',

    volume_module => 'HTFeed::PackageType::UCM::Volume',

    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( UCM_\w+\.(xml) | \d{8}\.(jp2)$)/x,

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
            file_pattern => qr/^\d{8}.(jp2)$/,
            required     => 1,
            content      => 1,
            jhove        => 1,
            utf8         => 0
        },
    },

    # The list of stages to run to successfully ingest a volume
    stage_map => {
        ready             => 'HTFeed::PackageType::UCM::Unpack',
        unpacked          => 'HTFeed::PackageType::UCM::ImageRemediate',
        images_remediated => 'HTFeed::PackageType::UCM::SourceMETS',
        src_metsed        => 'HTFeed::VolumeValidator',
        validated         => 'HTFeed::Stage::Pack',
        packed            => 'HTFeed::PackageType::UCM::METS',
#        metsed            => 'HTFeed::Stage::Handle',
#        handled           => 'HTFeed::Stage::Collate',
    },


    # What PREMIS events to include in the source METS file
    source_premis_events => [
        # capture - included manually
        'image_compression',
        'source_mets_creation',
        'page_md5_create',
        'mets_validation',
    ],

     # What PREMIS event types  to extract from the source METS and include in the HT METS
    source_premis_events_extract => [
        'capture',       
        'image_compression',
        'source_mets_creation',
        'page_md5_create',
    ],

    # What PREMIS events to include (by internal PREMIS identifier,
    # configured in config.yaml)
    premis_events => [
        'page_md5_fixity',
        'package_validation',
        'zip_compression',
        'zip_md5_create',
        'ingestion',
    ],

    source_mets_file => qr/^UCM_\w+\.xml$/,

    validation => {
      'HTFeed::ModuleValidator::JPEG2000_hul' => {
          'layers' => v_eq( 'codingStyleDefault', 'layers', '8' ),
          'resolution'      => v_and(
              v_ge( 'xmp', 'xRes', 300 ), # should work even though resolution is specified as NNN/1
              v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
          ),
      }
    }

};

__END__

=pod

This is the package type configuration file for Madrid's locally produced content.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('ucm');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2011 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
