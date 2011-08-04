package HTFeed::PackageType::HathiTrust;

use warnings;
use strict;
use base qw(HTFeed::PackageType);

our $identifier = 'ht';

our $config = {
    
    %{$HTFeed::PackageType::config},
    description => 'HathiTrust AIP',

    volume_module => 'HTFeed::PackageType::HathiTrust::Volume',

    filegroups => {
        image => {
            prefix => 'IMG',
            use => 'image',
            required => 1,
            jhove => 1,
            utf8 => 0,
        },
        ocr => { 
            prefix => 'OCR',
            use => 'ocr',
            required => 0,
            jhove => 0,
            utf8 => 1,
            content => 1
        },
        hocr => { 
            use => 'coordOCR',
            required => 0,
            jhove => 0,
            utf8 => 1,
        }
    },

   # source_mets_file => qr/\w+\.xml$/,
   # source_mets_mets_path =>

    # what stage to run given the current state
    stage_map => {
        ready 	 => 'HTFeed::Dataset::Stage::UnpackText',
        unpacked => 'HTFeed::Dataset::Stage::Pack',
		packed   => 'HTFeed::Dataset::Stage::Collate'
    },
};

__END__

