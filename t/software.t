#!/usr/bin/perl

use warnings;
use strict;
use HTFeed::Volume;
use HTFeed::VolumeValidator;
use HTFeed::Log {root_logger => 'INFO, screen'};
use Test::More tests => 9;
use HTFeed::Config qw(set_config get_tool_version);
use FindBin;


BEGIN {
    use_ok('HTFeed::Volume');
    use_ok('HTFeed::METS');
    use_ok('HTFeed::Config');
}

set_config(0,'stop_on_error');

my $mets = new HTFeed::METS(
    volume => new HTFeed::Volume(
        namespace   => 'test',
        objid       => '39015000000003',
        packagetype => 'simple'
    )
);

#TODO check this test method
like( get_tool_version("GROOVE"),
    qr/$FindBin::Script .*\d+.*/, "toolver_groove" );

like( get_tool_version("EXIFTOOL"),
    qr/Image::ExifTool \d+\.\d+/, "toolver_exiftool" );
like( get_tool_version("XERCES"), qr/(lib)?xerces-c(3.1)?[- \d\w.]+/i, "toolver_xerces" );
like( get_tool_version("JHOVE"),  qr/jhove \d\.\d+/i,    "toolver_jhove" );
like( get_tool_version("DIGEST_MD5"),
    qr/Digest::MD5 \d\.\d+/, "toolver_digest_md5" );
like( get_tool_version("GPG"), qr/gnupg[- \d\w.]+/i, "toolver_gpg" );

#TODO test bad package for error catching
