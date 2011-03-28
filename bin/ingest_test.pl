#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Job;
use HTFeed::Run;

use Getopt::Long;
use HTFeed::StagingSetup;

# autoflush STDOUT
$| = 1;

my $ignore_errors = 0;
my $clean = 1;

GetOptions ( 
    "ignore_errors!" => \$ignore_errors, 
    "clean!" => \$clean) or usage();

# read args
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;
my $startstate  = shift;

usage() unless ($objid and $namespace and $packagetype);

sub usage {
    ## -i not doesn't work
    # print "usage: ingest_test.pl [ -i | --ignore_errors ] [ --no-clean ] packagetype namespace objid [ state ]\n";
    print "usage: ingest_test.pl [ --no-clean ] packagetype namespace objid [ state ]\n";
    exit 0;
}

# make staging dirs
HTFeed::StagingSetup::make_stage();

my $job;

# instantiate first job for ingest
$job = HTFeed::Job->new(pkg_type => $packagetype, namespace => $namespace, id => $objid, status => $startstate, callback => \&new_job);

# run successive jobs until new_job fails to create one
while($job){
    run_job($job,$clean);
}

# callback method for $job->update
# reports on success of stage and next state
# and instantiates next $job
sub new_job{
    my ($ns,$id,$status,$release,$fail) = @_;
    
    # print results of last stage
    my $stage = $job->stage_class;
    my $report = "$ns $id: $stage ";
    $report .= 'FAILED    ' if ($fail);
    $report .= 'SUCCEEDED ' if (! $fail);
    $report .= " - New status: $status\n";
    print $report;
    
    if ($release){
        # ingest complete
        $job = undef;
        print "Ingest complete\n";
    }
    else{
        # instantiate job for next stage
        $job = HTFeed::Job->new(pkg_type => $packagetype, namespace => $namespace, id => $objid, status => $status, callback => \&new_job);
    }
}

