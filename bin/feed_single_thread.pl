#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTFeed::Log { root_logger => 'INFO, dbi' };
use HTFeed::Version;

use HTFeed::StagingSetup;
use HTFeed::Job;

use HTFeed::Config;
use HTFeed::Volume;
use HTFeed::DBTools qw(get_queued lock_volumes count_locks update_queue disconnect);
use Log::Log4perl qw(get_logger);

use HTFeed::ServerStatus qw(continue_running_server check_disk_usage);
use Sys::Hostname;
use Mail::Mailer;
use POSIX ":sys_wait_h";


print("feedd running, waiting for something to ingest, pid = $$\n");

my $process_id = $$;
my $subprocesses = 0;
my @jobs = ();

my $clean = get_config('clean');

# run end block on SIGINT and SIGTERM
$SIG{'INT'} =
    sub {
        exit;
    };

$SIG{'TERM'} = 
    sub {
        exit;
    };


HTFeed::StagingSetup::make_stage();

my $i = 0;
while( continue_running_server() ){
  while (my $job = get_next_job()){
      $job->run_job($clean);
  }
  sleep 15;
}
print "Stop file found; finishing work on locked volumes...\n";
exit(1);

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
                push (@jobs, $job);
            }
            $sth->finish();
        }
        disconnect();
    };
    if($@){
        get_logger()->warn("daemon db operation failed: $@");
    }
}

1;

__END__
