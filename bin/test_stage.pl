#!/usr/bin/perl

use strict;
use warnings;
use HTFeed::Volume;
use HTFeed::Log {root_logger => 'TRACE, screen'};
use HTFeed::Config qw(set_config);

use Getopt::Long;
my $debug = 0;
my $clean = 0;

my $result = GetOptions(
    "verbose+" => \$debug,
    "clean!"   => \$clean
) or usage();

# read args
my $module = shift;
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;
my $dir = shift;

usage() unless ($module and $objid and $namespace and $packagetype);

set_config($dir,'staging'=>'ingest') if (defined $dir);

# run validation
my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);

eval<<EOT;
    use $module;
    my \$stage = $module->new(volume => \$volume);
    \$stage->run();

    if (\$stage->succeeded()){
        print "success!\n";
    }
    else {print "failure!\n";}

    if(\$clean) {
        print "cleaning stage:\n";
        \$stage->clean();
    }
EOT

if($@) {
    die($@);
}

sub usage {
    print "usage: test_stage.pl [--verbose --clean] stage_module packagetype namespace objid [staging dir]\n";
}
