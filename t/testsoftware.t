#!/usr/bin/perl

use warnings;
use strict;
#use HTFeed::Volume;
#use HTFeed::VolumeValidator;
use HTFeed::Log {root_logger => 'INFO, screen'};
use Test::More tests => 11;
use HTFeed::Config qw(set_config);

# check for legacy environment vars
unless (defined $ENV{GROOVE_WORKING_DIRECTORY} and defined $ENV{GROOVE_CONFIG}){
    print "GROOVE_WORKING_DIRECTORY and GROOVE_CONFIG must be set\n";
    exit 0;
}


BEGIN {
    use_ok('HTFeed::Volume');
    use_ok('HTFeed::METS');
    use_ok('HTFeed::Config');
}

set_config(0,'stop_on_error');

my $mets = new HTFeed::METS(
    volume => new HTFeed::Volume(
        namespace   => 'mdp',
        objid       => '39015000000003',
        packagetype => 'google'
    )
);
like( $mets->get_tool_version("GROOVE"),
    qr/$0 git rev [a-z0-f]{40}/, "toolver_groove" );
like( $mets->get_tool_version("EXIFTOOL"),
    qr/Image::ExifTool \d\.\d+/, "toolver_exiftool" );
like( $mets->get_tool_version("XERCES"), qr/xerces-c \d\.\d+/, "toolver_xerces" );
like( $mets->get_tool_version("JHOVE"),  qr/jhove \d\.\d+/,    "toolver_jhove" );
like( $mets->get_tool_version("DIGEST_MD5"),
    qr/Digest::MD5 \d\.\d+/, "toolver_digest_md5" );
like( $mets->get_tool_version("GPG"), qr/gnupg[-\d\w.]+/, "toolver_gpg" );
is( $mets->local_directory_version("notapackage"),"notapackage","toolver_badlocal");
is( $mets->perl_mod_version("notamodule"),"notamodule","toolver_badmod");
