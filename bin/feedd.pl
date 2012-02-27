#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTFeed::Log { root_logger => 'INFO, dbi' };
use HTFeed::Version;

use HTFeed::StagingSetup;
use HTFeed::Run;

use HTFeed::Config;
use HTFeed::Volume;
use HTFeed::DBTools qw(get_queued lock_volumes count_locks update_queue disconnect);
use Log::Log4perl qw(get_logger);
use Filesys::Df;
use HTFeed::Job;

use HTFeed::ServerStatus;
use Sys::Hostname;
use Mail::Mailer;

print("feedd running, waiting for something to ingest, pid = $$\n");

my $process_id = $$;
my $subprocesses = 0;
my @jobs = ();
my %locks_by_key = ();
my %locks_by_pid = ();

my $clean = get_config('daemon'=>'clean');

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

# run end block on SIGINT and SIGTERM
$SIG{'INT'} =
    sub {
        exit;
    };

$SIG{'TERM'} = 
    sub {
        exit;
    };

# exit right away if stop file is set
if( ! continue_running_server() ) {
	warn 'feedd connot run when locked';
	exit 1;
}

HTFeed::StagingSetup::make_stage($clean);

my $i = 0;
while( continue_running_server() ){
    my $df = df(get_config('ram_disk'));
#    warn("Iteration $i: RAM disk has $bfree blocks free\n");$i++;
    my $pctused = df(get_config('ram_disk'))->{per};
    if( $pctused > get_config('ram_fill_limit') * 100) {
        die("RAM disk is $pctused% full!\n");
    }
    while (($subprocesses < get_config('volumes_in_process_limit')) 
            and (my $job = get_next_job())){
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
exit(1);

# fork, lock job, increment $subprocess
sub spawn{
    my $job = shift;
    # make sure DBI is disconnected before fork
    disconnect();
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

# wait, decrement subprocess count and release lock
sub wait_kid{
    my $pid = wait();
    if ($pid > 0){
        # remove old job from lock table
        release_job($pid);
        get_logger()->trace("released $pid");
        return $pid;
    }
    return;
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
                # instantiate HTFeed::Job
                my $job = HTFeed::Job->new(@{$job_info},\&update_queue);
                
                my $locked = is_locked($job);
                my $runnable = $job->runnable;
                
                if (! $locked){
                    if ($runnable){
                        # $job ok
                        push (@jobs, $job);
                    }else{
                        # $job has a bad state, release it
                        get_logger()->warn( 'Bad queue status', objid => $job->id, namespace => $job->namespace, detail => 'Volume found locked in unrunnable status: '. $job->status );
                        update_queue($job->namespace, $job->id, 'punted', 1, 1);
                    }
                }
            }
            $sth->finish();
        }
        disconnect();
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
    # clean up on exit of original pid (i.e. don't clean on END of fork()ed pid)
    if($$ eq $process_id){
        my @kid_pids = keys %locks_by_pid;
        
        # parent kills kids
        print "killing child procs...\n";
        kill 2, keys %locks_by_pid;
		sleep 20;

		# make sure kids are really gone
        my $kill9s = 0;
        while(_kids_remaining()){
            # send email evey 3 minutes
            $kill9s++;
            unless($kill9s % 9){
                _will_not_die_message($kill9s * 20);
            }

            kill 9, keys %locks_by_pid;
            sleep 20;
        }
        
        # delete staging dirs
        if ($clean){
            print "cleaning staging dirs...\n";
            # delete everything in staging, except download
            HTFeed::StagingSetup::clear_stage();

            # release all locks
            print "releasing db locks...\n";
            HTFeed::DBTools::reset_in_flight_locks();   
        }
        
        # wait before exiting if we're exiting with a non zero status (i.e. we died)
        # this prevents waiting to exit when we are sent SIGINT
        if ($?){
            print "Waiting 30 seconds (so we don't respawn too fast out of inittab)\n";
            sleep 30;            
        }
    }

    warn("feedd process $$ terminating");
}

sub _kids_remaining{
    my $count = kill 0, keys %locks_by_pid;
    return $count;
}

sub _will_not_die_message{
    my $seconds = shift;
    my $host = hostname;
    my $kid_cnt = _kids_remaining();
    my $message = "Feedd process $$ unable to exit for $seconds seconds. Unable to kill $kid_cnt children.\n" . 
                'Child pids: ' . join(q(, ),(keys %locks_by_pid));
    
    warn $message;
    
    # send email
    my $mailer = new Mail::Mailer;
    $mailer->open({ 'Subject' => "feedd zombie on $host",
                    'To' => get_config('admin_email')});
    
    print $mailer $message;
    $mailer->close() or warn("Couldn't send message: $!");    
}

1;

__END__
