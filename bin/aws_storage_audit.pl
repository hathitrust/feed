#!perl

use HTFeed::Storage::S3;
use HTFeed::StorageAudit;
use HTFeed::Config qw(get_config);
use HTFeed::Log {root_logger => 'INFO, screen'};

my $audit = HTFeed::StorageAudit->new(%{get_config('aws_audit')});

$audit->run;
