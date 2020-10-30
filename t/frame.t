#!/usr/bin/perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use AWS;
use HTFeed::FRAME;
use Test::More tests => 8;
use Data::Dumper;

my $data = AWS::list_objects('emma-ht-queue-staging');
is(scalar @{$data->{'Contents'}}, 2, '2 objects in initial fake AWS bucket list');
is(@{$data->{'Contents'}}[0]->{'Key'}, 'frame_test.zip', 'frame_test.zip');
is(@{$data->{'Contents'}}[1]->{'Key'}, 'frame_test.xml', 'frame_test.xml');
$data = AWS::list_objects('emma-ht-queue-staging', 'frame_test.xml');
is(scalar @{$data->{'Contents'}}, 1, '1 object in subsequent fake AWS bucket list');
is(@{$data->{'Contents'}}[0]->{'Key'}, 'frame_test_2.txt', 'frame_test_2.txt');

my $frame = HTFeed::FRAME->new(bucket => 'emma-ht-queue-staging',
                               dest   => '/tmp/prep/toingest/emma/');
$frame->run();

ok(-f '/tmp/prep/toingest/emma/frame_test.zip', '/tmp/prep/toingest/emma/frame_test.zip');
ok(-f '/tmp/prep/toingest/emma/frame_test.xml', '/tmp/prep/toingest/emma/frame_test.xml');
ok(-f '/tmp/prep/toingest/emma/frame_test_2.zip', '/tmp/prep/toingest/emma/frame_test_2.zip');

done_testing();
