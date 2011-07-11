#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Version;
use HTFeed::Job;
use HTFeed::Run;

use Getopt::Long;
use HTFeed::StagingSetup;

use HTFeed::Config qw(get_config set_config);

set_config('1','debug');
my $debug = $INC{"perl5db.pl"}; # are we running in a debugger?

# autoflush STDOUT
$| = 1;

my $ignore_errors = 0;
my $clean = 1;
my $always_fail = 0;

GetOptions ( 
    "ignore_errors!" => \$ignore_errors, 
    "clean!"         => \$clean,
    "fail"           => \$always_fail,
) or usage();

# read args
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;
my $startstate = (shift or 'ready');

usage() unless ($objid and $namespace and $packagetype);

sub usage {
    print "usage: ingest_test.pl [ -i | --ignore_errors ] [ -f | --fail ] [ --no-clean ] packagetype namespace objid [ state ]\n";
    exit 0;
}

# make staging dirs
HTFeed::StagingSetup::make_stage();

my $job;

# instantiate first job for ingest
$job = HTFeed::Job->new(pkg_type => $packagetype, namespace => $namespace, id => $objid, status => $startstate, callback => \&new_job);

# run successive jobs until new_job fails to create one

if ($ignore_errors){
    while($job){
        # force success
        run_job($job,$clean,0);
    }
}
elsif ($always_fail){
    while($job){
        # force failure
        run_job($job,$clean,1);    
    }
}
else{
    while($job){
        # use actual failure or success
        run_job($job,$clean);
    }
}

HTFeed::StagingSetup::clear_stage() if ($clean);

# callback method for $job->update
# reports on success of stage and next state
# and instantiates next $job
sub new_job{
    my ($ns,$id,$status,$release,$fail) = @_;

    print "New status: $status\n";
    
    if ($release){
        # break before exit (only applies to debugger)
        print "Last chance to do a postmertem before \$job is gone\n" if($debug);
        $DB::single = 1;

        $job = undef;
        print "Lock released\n";
    }
    else{
        # instantiate job for next stage
        my $failure_count = $job->failure_count;
        $failure_count++ if ($fail);
        
        # break before instantiating next job (only applies to debugger)
        print "Breaking before next job instantiation\n" if($debug);
        $DB::single = 1;
        
        #print "Instantiating new job($packagetype, $namespace, $objid, $status, $failure_count,\&new_job)\n";
        $job = HTFeed::Job->new($packagetype, $namespace, $objid, $status, $failure_count,\&new_job);
    }
}

__END__

=head1 NAME

    ingest_test.pl - add volumes to Feedr queue

=head1 SYNOPSIS

ingest_test.pl [[ -i | --ignore_errors ] | [ -f | --fail]] [ --no-clean ] packagetype namespace objid [ state ]\n

=cut


