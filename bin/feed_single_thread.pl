use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTFeed::Log { root_logger => 'INFO, dbi, screen' };
use HTFeed::Version;

use HTFeed::StagingSetup;
use HTFeed::Job;

use HTFeed::Config qw(get_config set_config);
use HTFeed::Volume;
use HTFeed::DBTools qw(get_queued lock_volumes count_locks update_queue disconnect);
use Log::Log4perl qw(get_logger);
use File::Path qw(remove_tree);

use HTFeed::ServerStatus qw(continue_running_server check_disk_usage);
use Sys::Hostname;
use Mail::Mailer;
use POSIX ":sys_wait_h";

# dynamically determine tmp dir based on hostname
my $node_staging = get_config('staging_root') . '/'. hostname;
set_config($node_staging,'staging_root');

print("feedd running, waiting for something to ingest, pid = $$\n");


my $process_id = $$;
my $subprocesses = 0;
my @jobs = ();

my $clean = get_config('clean');

# run end block on SIGINT and SIGTERM
$SIG{'INT'} =
    sub {
      print "Caught SIGINT\n";
      if($clean) {
        print "cleaning up $node_staging..\n";
        remove_tree $node_staging if $clean;
      }
      print "releasing locked volumes..\n";
      HTFeed::DBTools::reset_in_flight_locks();
        exit;
    };

$SIG{'TERM'} = 
    sub {
      print "Caught SIGTERM; releasing locked volumes..\n";
      if($clean) {
        print "cleaning up $node_staging..\n";
        remove_tree $node_staging if $clean;
      }
      print "releasing locked volumes..\n";
      HTFeed::DBTools::reset_in_flight_locks();
        exit;
    };


HTFeed::StagingSetup::make_stage();

my $i = 0;
while( continue_running_server() ){
  while (my $job = get_next_job()){
    get_logger()->info("next job: " . $job->{namespace} . "." . $job->{id} . " " . $job->stage_class);
    # don't re-use database connection in child; maybe chicken-waving since we
    # aren't doing anything in the parent while we wait for the child, but it
    # shouldn't hurt, and it should avoid surprises later
    disconnect();
    my $pid = fork();
    if( $pid ) {
      # parent; wait on child
      my $finished_pid = 0;
      while($finished_pid != $pid) {
        $finished_pid = wait();
      }
    } elsif (defined $pid) {
      $job->run_job($clean);
      exit(0);
    } else {
      die("Couldn't fork: $!");
    }
  }
  sleep 15;
}
print "Exiting ... \n";
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
