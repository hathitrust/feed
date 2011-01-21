package HTFeed::PackageType::Audio;
use HTFeed::PackageType;
use base qw(HTFeed::PackageType);
use strict;

our $identifier = 'audio';

our $config = {
    volume_module => 'HTFeed::Volume',

    # Regular expression that distinguishes valid files in the file package
    # HTML OCR is valid for the package type but only expected/required for UC1
    valid_file_pattern => qr/^( 
    checksum\.md5 |
    \w+\.(xml) |
    [ap]m\d{2,8}.(wav)
    )/x,

    # A set of regular expressions mapping files to the filegroups they belong
    # in
    filegroups => {
        archival => { 
            prefix => 'AM',
            use => 'archival',
            file_pattern => qr/am.*\.wav$/,
            required => 1,
            content => 1,
            jhove => 1,
            utf8 => 0
        },

        production => { 
            prefix => 'PM',
            use => 'production',
            file_pattern => qr/pm.*\.wav$/,
            required => 1,
            content => 1,
            jhove => 1,
            utf8 => 0
        }
    },

    source_mets_file => qr/\w+.xml$/,

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 0,

    # The list of stages to run to successfully ingest a volume.
    stages_to_run => [qw(
    HTFeed::PackageType::Audio::VolumeValidator
    HTFeed::PackageType::Audio::METS
    HTFeed::Handle
    HTFeed::Zip
    HTFeed::Collate
    )],


    # The HTFeed::ModuleValidator subclass to use for validating
    # files with the given extensions
    module_validators => {
        'wav'  => 'HTFeed::ModuleValidator::WAV_hul',
    },

    # Validation overrides
    validation => {
    },

    validation_run_stages => [
    qw(validate_file_names
    validate_filegroups_nonempty
    validate_consistency
    validate_mets_consistency
    validate_checksums
    validate_utf8
    validate_metadata)
    ],

    # What PREMIS events to include (by internal PREMIS identifier, 
    # configured in config.yaml)
    # TODO: determine Audio HT PREMIS events
    # TODO: determine Audio PREMIS source METS events toe xtract
    premis_events => [
    ],

    # filename extensions not to compress in zip file
    uncompressed_extensions => [],


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
