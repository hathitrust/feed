use warnings;
use strict;

## here for debug
use Data::Dumper;

use DBI;

use HTFeed::Version;
use HTFeed::StagingSetup;
use HTFeed::Run;

use HTFeed::Config;
use HTFeed::Volume;
use HTFeed::Log { root_logger => 'INFO, dbi, screen' };
use HTFeed::DBTools qw(get_queued lock_volumes count_locks);
#use Log::Log4perl qw(get_logger);

my $process_id = $$;
my $subprocesses = 0;
my @jobs = ();
my %locks_by_key = ();
my %locks_by_pid = ();
## TODO: set this somewhere else
my $clean = 1;

# kill children on SIGINT, SIGTERM
$SIG{'INT'} =
    sub {
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
        while ($subprocesses){
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
    };

HTFeed::StagingSetup::make_stage($clean);

while(! exit_condition()){
    while (($subprocesses < get_config('volumes_in_process_limit')) and (my $job = get_next_job())){
        spawn($job);
    }
    wait_kid() or sleep 15;
}
print "Finishing work on locked volumes...\n";
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
    return (-e get_config('daemon'=>'stop_file'));
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
    my $needed_volumes = get_config('volumes_in_process_limit') - count_locks();
    if ($needed_volumes > 0){
        lock_volumes($needed_volumes);
    }
    
    if (my $sth = get_queued()){
        while(my $job = $sth->fetchrow_hashref()){
            push (@jobs, $job) if (! is_locked($job) and can_run_job($job));
        }
    }
}

sub is_locked{
    my $job = shift;
    return exists $locks_by_key{$job->{ns}}{$job->{objid}};
}

sub lock_job{
    my ($pid,$job) = @_;
    $locks_by_key{$job->{ns}}{$job->{objid}} = $job;
    $locks_by_pid{$pid} = $job;
    $subprocesses++;
    print "LOCK $job->{ns}.$job->{objid} to $pid! $subprocesses in flight\n";
}

sub release_job{
    my $pid = shift;
    my $job = $locks_by_pid{$pid};
    delete $locks_by_pid{$pid};
    delete $locks_by_key{$job->{ns}}{$job->{objid}};
    $subprocesses--;
    print "RELEASE $job->{ns}.$job->{objid} from $pid! $subprocesses in flight\n";
}

END{
    # clean up on exit of original pid (i.e. don't clean on END of fork()ed pid) if $clean
    if (($$ eq $process_id) and $clean){
        # delete everything in staging, except download
        HTFeed::StagingSetup::clear_stage();
        
        # release all locks
        HTFeed::DBTools::reset_in_flight_locks();
    }
}

1;

__END__
