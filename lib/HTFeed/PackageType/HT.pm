package HTFeed::PackageType::HT;

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
            prefix => 'HTML',
            use => 'coordOCR',
            required => 0,
            jhove => 0,
            utf8 => 1,
        }
    },

    # source_mets_file => qr/\w+\.xml$/,

    # use HTFeed::Volume::set_stage_map to setup a workflow with this packagetype
    stage_map => undef,
};

__END__

