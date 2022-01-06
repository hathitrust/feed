package HTFeed::QueueRunner;

use HTFeed::StagingSetup;
use HTFeed::Bunnies;

# Gets items to ingest from queue; processes them start to finish.

sub new {
  my $class = shift;
  my %params = @_;

  my $self = {};
  bless($self, $class);

  # TODO: HTFeed::VolumeList that can be used as the queue instead
  $self->{queue} = $params->{queue} || HTFeed::Bunnies->new();
  $self->{clean} = $params->{clean} || get_config('clean');
  # update status in the database by default
  $self->{update_db} = $params->{update_db} || 1;
  $self->{staging_root} = $params->{staging_root} || $self->node_stage_dir;

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
  while( my $job = $self->next_job() ){
    while($job){
      $self->fork_and_wait($job);
      $job = $job->successor;
    }
  }
}

sub fork_and_wait {
  my $self = shift;
  my $job = shift;

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

sub next_job {
  my $self = shift;
  my $job_info = $self->{queue}->next_job;

  return HTFeed::Job->new(@{$job_info},$self->finish_callback($job_info));
}

sub finish_callback {
  my $self = shift;
  my $job_info = shift;

  return sub {
    # Progress both in DB queue and in rabbitmq. Could implement more advanced
    # handling with rabbitmq for failure/retry here.
    $self->{queue}->finished($job_info);
    if($self->{update_db}) {
      update_queue(@_);
    }
  }
}

sub clean_and_exit {
  my $self = shift;
  if($self->{clean}) {
    print "cleaning up $self->{staging_root}..\n";
    remove_tree $self->{staging_root};
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
