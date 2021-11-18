package HTFeed::ProgressTracker;

use Net::Prometheus;
use HTFeed::Config qw(get_config);
use LWP::UserAgent;
use File::Basename;

use strict;
use warnings;

sub new {
  my $class = shift;

  my $job = shift || basename($0);
  my $success_interval = shift || $ENV{'JOB_SUCCESS_INTERVAL'};

  my $self = bless {}, $class;

  $self->{job} = $job;
  $self->{prom} = Net::Prometheus->new;
  $self->{ua} = LWP::UserAgent->new;

  $self->{records_so_far} = 0;
  $self->{start_time} = time();

  if($success_interval) { 
    $self->success_interval->set($success_interval);
  }

  $self->update_metrics;

  return $self;

}

sub update_metrics {
  my $self = shift;

  $self->duration->set(time() - $self->{start_time});
  $self->records_processed->set($self->{records_so_far});

  $self->push_metrics;

}

sub push_metrics {
  my $self = shift;

  # TODO: wipes out last_success with 0 on push. Need to wait to register
  # metric until we want to use it?

  my $job = $self->{job};
  my $url = get_config('pushgateway') . "/metrics/job/$job";
  my $data = $self->{prom}->render;

  $self->{ua}->post($url, Content => $data);


}

sub duration {
  my $self = shift;

  $self->{duration} ||= $self->{prom}->new_gauge(
    name => 'job_duration_seconds',
    help => 'Time spend running job in seconds'
  )

}

sub last_success {
  my $self = shift;

  $self->{last_success} ||= $self->{prom}->new_gauge(
    name => 'job_last_success',
    help => 'Last Unix time when job successfully completed'
  )
}

sub records_processed {
  my $self = shift;

  $self->{records_processed} ||= $self->{prom}->new_gauge(
    name => 'job_records_processed',
    help => 'Records processed by job'
  )
}

sub success_interval {
  my $self = shift;

  $self->{success_interval} ||= $self->{prom}->new_gauge(
    name => 'job_expected_success_interval',
    help => 'Maximum expected time in seconds between job completions'
  )
}

1;
