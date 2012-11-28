package HTFeed::PackageType::DLXS;

#legacy DLPS content

use strict;
use warnings;
use base qw(HTFeed::PackageType);
use POSIX qw(ceil);
use HTFeed::XPathValidator qw(:closures);

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
        DLXS_[\w,]+\.(xml) |
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
        images_remediated    => 'HTFeed::PackageType::DLXS::OCRSplit',
        ocr_extracted => 'HTFeed::PackageType::DLXS::BibTargetRemove',
        target_removed => 'HTFeed::PackageType::DLXS::SourceMETS',
        src_metsed		=> 'HTFeed::PackageType::DLXS::VolumeValidator',
		validated	=> 'HTFeed::Stage::Pack',
		packed		=> 'HTFeed::PackageType::DLXS::METS',
        metsed		=> 'HTFeed::Stage::Handle',
        handled		=> 'HTFeed::Stage::Collate',
    },

    # What PREMIS events to include in the source METS file
    source_premis_events => [
         'capture',
#        'file_rename',
#        'source_md5_fixity',
        'target_remove',
        'image_header_modification',
        'ocr_normalize',
        'page_md5_create',
        'source_mets_creation',
        'mets_validation',
    ],

    # What PREMIS event types  to extract from the source METS and include in the HT METS
    source_premis_events_extract => [
        'capture',
#        'file_rename',
        'image_header_modification',
        'ocr_normalize',
        'page_md5_create',
        'source_mets_creation',
    ],

    premis_events => [
        'page_md5_fixity',
        'package_validation',
        'page_feature_mapping',
        'zip_compression',
        'zip_md5_create',
        'ingestion',
        'premis_migration', #optional 
    ],

    # Overrides for the basic PREMIS event configuration
    premis_overrides => {
        'ocr_normalize' =>
          { detail => 'Split OCR into one plain text OCR file per page', },
        'target_remove' => 
          { type => 'file deletion',
            detail => 'Remove bibliographic record targets' ,
            executor => 'MiU',
            executor_type => 'MARC21 Code',
            optional => 1,
            tools => ['GROOVE']
          },
    },

    source_mets_file => qr/^DLXS_[\w,]+\.xml$/,

    # Validation overrides - make/model not expected
    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            'camera'               => undef,
             'resolution'      => v_and(
                 v_ge( 'xmp', 'xRes', 300 ), # should work even though resolution is specified as NNN/1
                 v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
             ),
            'decomposition_levels' => sub {
                my $self = shift;

                my $xsize = $self->_findone("mix","width");
                my $ysize = $self->_findone("mix","length");

                my $maxdim = $xsize > $ysize ? $xsize : $ysize;

                my $expectedLevels = ceil(log($maxdim / 150.0)/log(2));
                my $actualLevels = $self->_findone('codingStyleDefault','decompositionLevels');

                if ($expectedLevels == $actualLevels) {
                    return 1;
                } else {
                    $self->set_error("BadValue", 
                        field => "codingStyleDefault_decompositionLevels", 
                        actual => $actualLevels,
                        expected => $expectedLevels);
                    return;
                }

            }
        }
    },

    # Allow gaps in numerical sequence of filenames?
    # Only some sequence gaps are allowed in legacy DLXS materials, e.g. for bib target removal.
    # This is checked in in DLXS/VolumeValidator.pm
    allow_sequence_gaps => 1,

    # Allow (but do not require) both a .tif and .jp2 image for a given sequence number
    allow_multiple_pageimage_formats => 1,

    # Create a preingest directory
    use_preingest => 1,

};
