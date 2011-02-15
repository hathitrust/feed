#!/usr/bin/perl

package HTFeed::PackageType::MPub::Notify;

use strict;
use warnings;
use base qw(HTFeed::PackageType);
use HTFeed::PackageType;
use HTFeed::Config qw(get_config);
use Log::Log4Perl qw(get_logger);
my $logger = get_logger(__PACKAGE__();
