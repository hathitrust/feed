# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'HTFeed::TestVolume' ); }

my $object = new HTFeed::TestVolume(namespace => 'namespace', packagetype => 'pkgtype');
isa_ok ($object, 'HTFeed::TestVolume');


