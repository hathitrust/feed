package HTFeed::PackageType::EPUB;

use warnings;
use strict;
use base qw(HTFeed::PackageType::SimpleDigital);
use HTFeed::XPathValidator qw(:closures);

our $identifier = 'simpledigital';

our $config = {

    %{$HTFeed::PackageType::Simple::config},
    description => 'Simple SIP format for cloud validator for native EPUB with optional PDF',

    volume_module => 'HTFeed::PackageType::Simple::Volume',


    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
    checksum\.md5 |
    meta\.yml |
    marc\.xml |
    [a-zA-Z0-9._-]+\.epub |
    [a-zA-Z0-9._-]+\.pdf |
    [a-zA-Z0-9._-]+\.txt |
    .*\.mets\.xml
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
        pdf => {
            prefix => 'PDF',
            use => 'pdf',
            file_pattern => qr/[a-zA-Z0-9._-]+\.pdf$/,
            required => 0,
            sequence => 0,
            content => 1,
            jhove => 0,
            utf8 => 0,
            # set to 0 to omit filegroup from structmap
            # (there is not a PDF file for every page, so including it in the
            # physical structmap wouldn't make much sense.)
            structmap => 0
        },
        text => {
            prefix => 'TEXT',
            use => 'text',
            file_pattern => qr/[a-zA-Z0-9._-]+\.txt$/,
            required => 1,
            sequence => 0,
            content => 1,
            jhove => 0,
            utf8 => 1,
            # set to 0 to omit filegroup from structmap
            # (there is not a PDF file for every page, so including it in the
            # physical structmap wouldn't make much sense.)
            structmap => 0
        },
        epub => {
            prefix => 'EPUB',
            use => 'epub',
            file_pattern => qr/[a-zA-Z0-9._-]+\.epub$/,
            required => 1,
            sequence => 0,
            content => 1,
            jhove => 0,
            utf8 => 0,
            # set to 0 to omit filegroup from structmap
            # (there is not a PDF file for every page, so including it in the
            # physical structmap wouldn't make much sense.)
            structmap => 0
        },
    },

    checksum_file => qr/checksum\.md5$/,

    # what stage to run given the current state
    stage_map => {
        ready             => 'HTFeed::PackageType::EPUB::Unpack',
        unpacked     => 'HTFeed::PackageType::EPUB::VerifyManifest',
        manifest_verified => 'HTFeed::PackageType::EPUB::SourceMETS',
        src_metsed        => 'HTFeed::PackageType::EPUB::VolumeValidator',
        validated  => 'HTFeed::Stage::Pack',
        packed     => 'HTFeed::PackageType::EPUB::METS',
        metsed     => 'HTFeed::Stage::Handle',
        handled    => 'HTFeed::Stage::Collate',
    },

    validation_run_stages => [
      qw(validate_file_names
      validate_filegroups_nonempty
      validate_consistency
      validate_checksums
      validate_utf8
      validate_metadata
      validate_epub
      validate_digitizer)
    ],

    # What PREMIS events to include in the source METS file
    source_premis_events => [
        # capture - included manually
        'page_md5_fixity',
        'source_mets_creation',
        'page_md5_create',
        'mets_validation',
    ],

     # What PREMIS event types  to extract from the source METS and include in the HT METS
    source_premis_events_extract => [
        'creation',       
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
        'premis_migration', #optional
    ],

    # override language about 'image and OCR' files
    premis_overrides => {
        'package_validation' => 
          { type => 'validation',
            detail => 'Validation of technical characteristics of EPUB files' ,
            executor => 'umich',
            executor_type => 'HathiTrust Institution ID',
            tools => ['EPUBCHECK']
          },
          'page_md5_fixity' => 
          { type => 'fixity check',
            detail => 'Validation of MD5 checksums for EPUB files',
            executor => 'umich',
            executor_type => 'HathiTrust Institution ID',
            tools => ['DIGEST_MD5']
          },
          'page_md5_create' => 
          { type => 'message digest calculation',
            detail => 'Creation of MD5 checksums for EPUB files',
            executor => 'umich',
            executor_type => 'HathiTrust Institution ID',
            tools => ['DIGEST_MD5']
          }
        },


    SIP_filename_pattern => '%s.zip',
#    SIP_filename_pattern => '',

    source_mets_file => '.*.mets.xml',

    checksum_file => 'checksum.md5',

    use_preingest => 1,

};

__END__

=pod

This is the package type configuration file for the simple cloud validation format.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('simple');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=cut
