#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTFeed::StagingSetup;
use HTFeed::Run;

use HTFeed::Config;
use HTFeed::Volume;
use HTFeed::Log { root_logger => 'INFO, dbi, screen' };
use HTFeed::DBTools qw(get_queued lock_volumes count_locks);
use Log::Log4perl qw(get_logger);
use Filesys::Df;

use HTFeed::Version;
print("feedd running, waiting for something to ingest\n");

my $process_id = $$;
my $subprocesses = 0;
my @jobs = ();
my %locks_by_key = ();
my %locks_by_pid = ();

my $clean = get_config('daemon'=>'clean');

# kill children on SIGINT, SIGTERM
$SIG{'INT'} =
    sub {
        warn("Process $$ received SIGINT/SIGTERM, cleaning up...\n");
        unless($$ eq $process_id){
            # child dies
            exit 0;
        }
        # parent kills kids
        kill 2, keys %locks_by_pid;
        exit 0;
    };
$SIG{'TERM'} = $SIG{'INT'};

# reread config on SIGHUP
# 
# Caveats: This won't affect the L4P settings.
#
$SIG{'HUP'} =
    sub {
        warn("Process $$ received SIGHUP, reloading configuration\n");
        while ($subprocesses){
            warn("Waiting for subprocess to exit\n");
            wait_kid();
        }
        # delete everything in staging, except download
        HTFeed::StagingSetup::clear_stage();
        # release all locks
        HTFeed::DBTools::reset_in_flight_locks();
        %locks_by_key = ();
        %locks_by_pid = ();

        HTFeed::Config::init();
        HTFeed::DBTools::_init();
        
        $clean = get_config('daemon'=>'clean');
    };

# exit right away if stop file is set
if( ! exit_condition() ) {
    HTFeed::StagingSetup::make_stage($clean);
}

my $i = 0;
while(! exit_condition()){
    my $bfree = df(get_config('ram_disk'))->{bfree} ;
#    warn("Iteration $i: RAM disk has $bfree blocks free\n");$i++;
    if( $bfree < 200*1024){
        die("RAM disk has only $bfree blocks free\n");
    }
    while (($subprocesses < get_config('volumes_in_process_limit')) and (my $job = get_next_job())){
        spawn($job);
    }
    wait_kid() or do {
        sleep 15;
    }
}
print "Stop file found; finishing work on locked volumes...\n";
while ($subprocesses){
    wait_kid();
}
# fork, lock job, increment $subprocess
sub spawn{
    my $job = shift;
    my $pid = fork();
    if ($pid){
        # parent
        lock_job($pid, $job);
    }
    elsif ( defined $pid ) {
        # child
        run_job($job, $clean);
        exit(0);
    }
    else{
        die("Couldn't fork: $!");
    }
}

# wait, spawns refreshed job for kid's volume if possible
# else decrement $subprocess and release lock
sub wait_kid{
    my $pid = wait();
    if ($pid > 0){
        # remove old job from lock table
        release_job($pid);
        return $pid;
    }
    return;
}

# determine if we are done
sub exit_condition{
    my $condition = -e get_config('daemon'=>'stop_file');

    return $condition;
}

sub get_next_job{
    my $job;

    if ($job = shift @jobs){
        return $job;
    }

    # @jobs is empty, fill it up from db
    fill_queue();
    if ($job = shift @jobs){
        return $job;
    }
    return;
}

sub fill_queue{
    # db ops were crashing, this will catch them, in which case
    # the internal queue will be starved until fill_queue runs again after the next wait()
    eval{
        my $needed_volumes = get_config('volumes_in_process_limit') - count_locks();
        if ($needed_volumes > 0){
            lock_volumes($needed_volumes);
        }
    
        if (my $sth = get_queued()){
            while(my $job_info = $sth->fetchrow_arrayref()){
                ## TODO: Make sure this works
                my $job = HTFeed::Job->new(@{$job_info},\&update_queue);
                ## if !can_run_job, $job will never be released
                push (@jobs, $job) if (! is_locked($job) and $job->runnable);
            }
            $sth->finish();
        }
    };
    if($@){
        get_logger()->warn("daemon db operation failed: $@");
    }
}

sub is_locked{
    my $job = shift;
    return exists $locks_by_key{$job->{namespace}}{$job->{id}};
}

sub lock_job{
    my ($pid,$job) = @_;
    $locks_by_key{$job->{namespace}}{$job->{id}} = $job;
    $locks_by_pid{$pid} = $job;
    $subprocesses++;
    print "LOCK $job->{namespace}.$job->{id} to $pid! $subprocesses in flight\n";
}

sub release_job{
    my $pid = shift;
    my $job = $locks_by_pid{$pid};
    delete $locks_by_pid{$pid};
    delete $locks_by_key{$job->{namespace}}{$job->{id}};
    $subprocesses--;
    print "RELEASE $job->{namespace}.$job->{id} from $pid! $subprocesses in flight\n";
}

END{
    # clean up on exit of original pid (i.e. don't clean on END of fork()ed pid) if $clean
    if (($$ eq $process_id) and $clean){
        # delete everything in staging, except download
        HTFeed::StagingSetup::clear_stage();
        
        # release all locks
        HTFeed::DBTools::reset_in_flight_locks();
        print "Waiting 30 seconds (so we don't respawn too fast out of inittab)\n";
        sleep 30;
    }

}

1;

__END__
