package HTFeed::PackageType::IslamicManuscripts;
use HTFeed::PackageType;
use base qw(HTFeed::PackageType::MPub);
use strict;

our $identifier = 'islam';

our $config = {
    %{$HTFeed::PackageType::MPub::config},
    filegroups => {
	image => {
	    prefix => 'IMG',
	    use => 'image',
	    file_pattern => qr/\d{8}\.(jp2|tif)$/,
	    required => 1,
	    content => 1,
	    jhove => 1,
	    utf8 => 0
	}
    },

    # TODO: review/fix Islamic MSS PREMIS events
    premis_events => [
	'empty_ocr_creation',
	'page_md5_fixity',
	'page_md5_create',
	'package_validation',
	'zip_compression',
	'zip_md5_create',
#	'ht_mets_creation',
	'ingestion',
    ],
};

1;

__END__
