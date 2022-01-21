package HTFeed::QueueRunner;

use HTFeed::StagingSetup;
use HTFeed::Bunnies;
use HTFeed::Config qw(get_config set_config);
use HTFeed::DBTools qw(update_queue);
use Log::Log4perl qw(get_logger);
use HTFeed::Job;
use Sys::Hostname qw(hostname);
use File::Path qw(remove_tree);

use strict;

# Gets items to ingest from queue; processes them start to finish.

sub new {
  my $class = shift;
  my %params = @_;

  my $self = {};
  bless($self, $class);

  # TODO: HTFeed::VolumeList that can be used as the queue instead
  $self->{queue} = $params{queue} || HTFeed::Bunnies->new();
  $self->{clean} = $params{clean} || get_config('clean');
  # update status in the database by default
  $self->{staging_root} = $params{staging_root} || $self->node_stage_dir;
  $self->{timeout} = $params{timeout};
  $self->{update_db} = $params{update_db};
  $self->{update_db} = 1 if not defined $self->{update_db};
  # for testing
  $self->{should_fork} = $params{should_fork};
  $self->{should_fork} = 1 if not defined $self->{should_fork};

  set_config($self->{staging_root}, 'staging_root');
  HTFeed::StagingSetup::make_stage();

  return $self;

}

sub node_stage_dir {
  my $self = shift;

  get_config('staging_root') . '/'. hostname;
}

sub run {
  my $self = shift;

  $self->setup_signal_handlers;

  print("feedd QueueRunner running, waiting for something to ingest, pid = $$\n");

  while( my $job_info = $self->{queue}->next_job($self->{timeout}) ){
    $self->marshal_and_run($job_info);
  }
}

sub marshal_and_run {
  my $self = shift;
  my $job_info = shift;

  my $job = HTFeed::Job->new(%{$job_info},callback=>$self->finish_callback());

  if($self->{should_fork}) {
    $self->fork_and_run_job_sequence($job);
  } else {
    $self->run_job_sequence($job);
  }

  $self->{queue}->finish($job_info);
}

sub run_job_sequence {
  my $self = shift;
  my $job = shift;

  while($job){
    get_logger()->info("next job: " . $job->namespace . "." . $job->id . " " . $job->stage_class);

    $job->run_job($self->{clean});
    $job = $job->successor;
  }
}

sub fork_and_run_job_sequence {
  my $self = shift;
  my $job = shift;

  # don't re-use database connection in child; maybe chicken-waving since we
  # aren't doing anything in the parent while we wait for the child, but it
  # shouldn't hurt, and it should avoid surprises later
  HTFeed::DBTools::disconnect();
  my $pid = fork();
  if( $pid ) {
    # parent; wait on child
    my $finished_pid = 0;
    while($finished_pid != $pid) {
      $finished_pid = wait();
    }
  } elsif (defined $pid) {
    # parent will handle signals
    delete $SIG{'INT'};
    delete $SIG{'TERM'};
    $self->run_job_sequence($job);
    exit(0);
  } else {
    die("Couldn't fork: $!");
  }
}

sub finish_callback {
  my $self = shift;

  return sub {
    if($self->{update_db}) {
      update_queue(@_);
    }
  }
}

sub clean_and_exit {
  my $self = shift;
  if($self->{clean} and -e $self->{staging_root}) {
    print "cleaning up $self->{staging_root}..\n";
    remove_tree($self->{staging_root});
  }
  exit;
}

sub setup_signal_handlers {
  my $self = shift;

  # run end block on SIGINT and SIGTERM
  $SIG{'INT'} =
  sub {
    print "Caught SIGINT\n";
    $self->clean_and_exit;
  };

  $SIG{'TERM'} = 
  sub {
    print "Caught SIGTERM\n";
    $self->clean_and_exit;
  };
}

1;
