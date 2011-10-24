package HTFeed::PackageType::DLXS;

#legacy DLPS content

use strict;
use warnings;
use base qw(HTFeed::PackageType);

our $identifier = 'dlxs';

our $config = {
	%{$HTFeed::PackageType::config},
	description => 'DLXS legacy content',
	volume_module => 'HTFeed::PackageType::DLXS::Volume',

	#Regular expression that distinguished valid files in the file package
	#TODO Determine correct file types
	valid_file_pattern => qr/^(
		checksum\.md5 |
		\w+.(xml)
	)/x,

	#Filegroup configuration
	filegroups => {},

	#what stage to run given the current state
	stage_map => {},

	#PREMIS EVENTS to include
	premis_events => {},

	#PREMIS overrides
	premis_overrides => {},

};
