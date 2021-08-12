package HTFeed::PackageType::EMMA;

use warnings;
use strict;
use base qw(HTFeed::PackageType);
use HTFeed::XPathValidator qw(:closures);

our $identifier = 'emma';

our $config = {

    %{$HTFeed::PackageType::config},
    description => 'SIP from EMMA',

    volume_module => 'HTFeed::PackageType::EMMA::Volume',

    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^(.*)/,

    # Configuration for each filegroup.
    # prefix: the prefix to use on file IDs in the METS for files in this filegruop
    # use: the 'use' attribute on the file group in the METS
    # file_pattern: a regular expression to determine if a file is in this filegroup
    # required: set to 1 if a file from this filegroup is required for each page
    # content: set to 1 if file should be included in zip file
    # jhove: set to 1 if output from JHOVE will be used in validation
    # utf8: set to 1 if files should be verified to be valid UTF-8
    filegroups => {
        emma => {
            prefix => 'EMMA',
            use => 'remediated',
            file_pattern => qr/^.*(?<!.mets.xml)$/,
            required => 1,
            sequence => 0,
            content => 1,
            jhove => 0,
            utf8 => 0
        },
    },

    # what stage to run given the current state
    stage_map => {
        ready            => 'HTFeed::PackageType::EMMA::Unpack',
        unpacked         => 'HTFeed::PackageType::EMMA::VirusScan',
        scanned         => 'HTFeed::PackageType::EMMA::SourceMETS',
        src_metsed    => 'HTFeed::Stage::Pack',
        packed           => 'HTFeed::PackageType::EMMA::METS',
        metsed           => 'HTFeed::Stage::Handle',
        handled          => 'HTFeed::Stage::Collate',
    },


    # What PREMIS events to include in the source METS file
    source_premis_events => [
        # creation - included manually
        'source_mets_creation',
        'virus_scan',
        'page_md5_create',
        'mets_validation',
    ],

     # What PREMIS event types  to extract from the source METS and include in the HT METS
    source_premis_events_extract => [
        'creation',
        'source_mets_creation',
        'page_md5_create',
        'virus_scan',
    ],

    # What PREMIS events to include (by internal PREMIS identifier,
    # configured in config.yaml)
    premis_events => [
        'zip_compression',
        'zip_md5_create',
        'ingestion',
    ],
    #
    # override language about 'image and OCR' files
    premis_overrides => {
          'page_md5_fixity' => 
          { type => 'fixity check',
            detail => 'Validation of MD5 checksums for content files',
            executor => 'umich',
            executor_type => 'HathiTrust Institution ID',
            tools => ['DIGEST_MD5']
          },
          'page_md5_create' => 
          { type => 'message digest calculation',
            detail => 'Creation of MD5 checksums for content files',
            executor => 'umich',
            executor_type => 'HathiTrust Institution ID',
            tools => ['DIGEST_MD5']
          },
          'virus_scan' => 
          { type => 'virus scan',
            detail => 'Scan for virus',
            executor => 'umich',
            executor_type => 'HathiTrust Institution ID',
            tools => ['CLAMAV']
          }
        },

    source_mets_file => '.*.mets.xml',

    SIP_filename_pattern => '%s.zip',

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
