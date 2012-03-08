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
		pageview\.dat |
		\w+\.(xml) |
		\d{8}.(html|jp2|tif|txt)
		)/x,

	#Filegroup configuration
    filegroups => {
		image => {
	   		prefix => 'IMG',
	   		use => 'image',
	   		file_pattern => qr/\d{8}\.(jp2|tif)$/,
	   		required => 1,
	   		content => 1,
	   		jhove => 1,
	   		utf8 => 0
		},
        ocr => {
            prefix => 'OCR',
            use => 'ocr',
            file_pattern => qr/\d{8}\.txt$/,
            required => 1,
            content => 1,
            jhove => 0,
            utf8 => 1
        },
    },

	#what stage to run given the current state
	stage_map => {
        ready       => 'HTFeed::PackageType::DLXS::Fetch',
        fetched     => 'HTFeed::PackageType::DLXS::ImageRemediate',
#        images_remediated => 'HTFeed::PackageType::DLXS::SourceMETS',
#        src_metsed		=> 'HTFeed::VolumeValidator',
#		validated	=> 'HTFeed::Stage::Pack',
#		packed		=> 'HTFeed::PackageType::MPubDCU::METS',
#        metsed		=> 'HTFeed::Stage::Handle',
#        handled		=> 'HTFeed::Stage::Collate',
    },

	#PREMIS EVENTS to include
	premis_events => {},

	#PREMIS overrides
	premis_overrides => {},

};
