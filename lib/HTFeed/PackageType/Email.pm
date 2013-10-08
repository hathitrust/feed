package HTFeed::PackageType::Email;

use warnings;
use strict;
use base qw(HTFeed::PackageType);

our $identifier = 'email';

our $config = {

    %{$HTFeed::PackageType::config},
    description => 'Bentley Historical Library Email Archive',
    volume_module => 'HTFeed::PackageType::Email::Volume',

	# pkg will contain
	# 1 or more mbox file
	# 1 csv & 2 xml files
	# 0 or more pst and/or zip files
    valid_file_pattern => qr/^(
        .*\.mbox |
        .*\.csv |
        .*\.xml |
		.*\.zip |
		.*\.pst
    )/x,

    filegroups => {
        submission => {
            prefix => 'SUB',
            use => 'submission',
            file_pattern => qr/.*/, #Need filegroup for METS processing, but pattern can be anything
            required => 1,
            content => 1,
        },
        mbox => {
            prefix => 'MBOX',
            use => 'mbox',
            file_pattern => qr/\w+\.mbox$/,
            required => 1,
            content => 1,
        },
    },

	# required files
    ead => qr/^\w+\.ead\.xml$/,
    manifest => qr/^\w+\.manifest\.xml$/,
    source_premis => qr/^\w+\.premis\.csv$/,

    stage_map => {
        'ready'         => 'HTFeed::PackageType::Email::Fetch',
        'fetched'       => 'HTFeed::PackageType::Email::VolumeValidator',
        'validated'     => 'HTFeed::PackageType::Email::Scan',
        'scanned'       => 'HTFeed::PackageType::Email::Parse',
        'parsed'        => 'HTFeed::PackageType::Email::Pack',
        'packed'        => 'HTFeed::PackageType::Email::METS',
        'metsed'        => 'HTFeed::PackageType::Email::Manifest',
        'manifested'    => 'HTFeed::PackageType::Email::Collate',
    },

    use_schema_caching => 0,

    validation_run_stages => [
        qw(validate_file_names
        validate_filegroups_nonempty
        validate_mbox
        validate_checksums)
    ],

    premis_events => [
    'page_md5_fixity',
    'package_validation',
    'zip_compression',
    'zip_md5_create',
    'ingestion',
    ],

    SIP_filename_pattern => '%s.zip',

};

__END__

=pod

This is the package type configuration file for Email.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('email');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
