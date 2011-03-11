package HTFeed::PackageType::Audio;

use strict;
use warnings;
use base qw(HTFeed::PackageType);
use HTFeed::PackageType::Audio::Volume;

our $identifier = 'audio';

our $config = {
    volume_module => 'HTFeed::PackageType::Audio::Volume',

    # Regular expression that distinguishes valid files in the file package
    # HTML OCR is valid for the package type but only expected/required for UC1
    valid_file_pattern => qr/^( 
	\w+\.(mets.xml) |
    [ap]m\d{2,8}.(wav) |
	\w+\.(jp2) |
	checksum\.md5 |
	notes\.txt
    )/x,

    # A set of regular expressions mapping files to the filegroups they belong
    # in
    filegroups => {
        	archival => { 
        	    prefix => 'AM',
        	    use => 'preservation',
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
			},

			image => {
				use => 'image',
				file_pattern => qr/\w+\.(jp2)$/,
				required => 0,
				content => 1,
				jhove => 1,
				utf8 => 0
			},

    },
	
	validation_run_stages => [
	qw(validate_file_names
	validate_filegroups_nonempty
	validate_consistency
	validate_mets_consistency
	validate_checksums
	validate_metadata)
	],

    checksum_file    => 0,
    source_mets_file => qr/\w+.xml$/,

    # Allow gaps in numerical sequence of filenames?
    allow_sequence_gaps => 0,

    stage_map => {
        ready             => 'HTFeed::PackageType::Audio::Unpack',
        unpacked          => 'HTFeed::PackageType::Audio::VolumeValidator',
        validated         => 'HTFeed::Stage::Pack',
        packed            => 'HTFeed::PackageType::Audio::METS',
        metsed            => 'HTFeed::Stage::Handle',
        handled           => 'HTFeed::Stage::Collate',
    },

	# The list of filegroups that contain files that will be validated
    # by JHOVE
    metadata_filegroups => [qw(image)],

    # The HTFeed::ModuleValidator subclass to use for validating
    # files with the given extensions
    module_validators => {
        'wav' => 'HTFeed::ModuleValidator::WAVE_hul',
		'jp2' => 'HTFeed::ModuleValidator::JPEG2000_hul',
    },

    # Validation overrides
    validation => {
    },


    # What PREMIS events to include (by internal PREMIS identifier, 
    # configured in config.yaml)
    # TODO: determine Audio HT PREMIS events
    # TODO: determine Audio PREMIS source METS events to extract
    source_premis_events_extract => [
    'capture',
    'manual quality review',
    'source mets creation',
    'message digest calculation',
    ],

    premis_events => [
    'page_md5_fixity',
    'package_validation',
    'zip_compression',
    'zip_md5_create',
    'ingestion',
    ],

    premis_overrides => {},

    # filename extensions not to compress in zip file
    uncompressed_extensions => [],


};

__END__

=pod

This is the package type configuration file for Audio.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('audio');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
