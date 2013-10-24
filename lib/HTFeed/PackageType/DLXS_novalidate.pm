package HTFeed::PackageType::DLXS_novalidate;

#legacy DLPS content

use strict;
use warnings;
use base qw(HTFeed::PackageType::DLXS);
use POSIX qw(ceil);
use HTFeed::XPathValidator qw(:closures);

our $identifier = 'dlxs_novalidate';

our $config = {
	%{$HTFeed::PackageType::DLXS::config},
	description => 'DLXS legacy content - reduced validation',

    # Validation overrides - make/model not expected
    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            'camera'               => undef,
            # disable JPEG2000 resolution checks
            'resolution'           => undef,
            'resolution_unit'      => undef,
            'decomposition_levels' => undef,
        },

        # disable TIFF resolution checks
        'HTFeed::ModuleValidator::TIFF_hul' => {
            'resolution' => undef,
            'resolution_unit' => undef,
        }
    },


    # disable filegroup consistency check
    validation_run_stages => [
        qw(validate_file_names
          validate_filegroups_nonempty
          validate_checksums
          validate_utf8
          validate_metadata)
    ],

    skip_validation => [
        'jpeg2000_size',
        'tiff_resolution',
        'sequence_skip',
        'missing_files',
    ],

    skip_validation_note => 'Material originally ingested as a pilot project without validation; reingested without validation for uplift to PREMIS 2.0.'

};
