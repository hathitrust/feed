package HTFeed::ProgressTracker;

use Net::Prometheus;
use HTFeed::Config qw(get_config);
use LWP::UserAgent;
use File::Basename;

use strict;
use warnings;

my $DEFAULT_REPORT_INTERVAL = 1000;

sub new {
  my $class = shift;
  my %params = @_;

  my $self = bless {}, $class;

  $self->{job} = $params{job} || $ENV{'JOB_NAME'} || basename($0);
  $self->{report_interval} = $params{report_interval} || $DEFAULT_REPORT_INTERVAL;
  my $success_interval = $params{success_interval} || $ENV{'JOB_SUCCESS_INTERVAL'};

  $self->{prom} = Net::Prometheus->new(
    disable_process_collector => 1,
    disable_perl_collector => 1
  );
  $self->{ua} = LWP::UserAgent->new;

  $self->{labels} = {};
  $self->{records_so_far} = 0;
  $self->{last_reported_records} = 0;
  $self->{start_time} = time();

  if($success_interval) {
    $self->success_interval->set($success_interval);
  }

  return $self;

}

sub start_stage {
  my $self = shift;
  my $stage = shift;

  # final counts from previous stage
  $self->update_metrics if $self->{stage};

  $self->{labels} = { labels => [ 'stage' ] };
  $self->{stage} = $stage;
  $self->{start_time} = time();
  $self->{records_so_far} = 0;

  # new stage
  $self->update_metrics;
}

sub inc {
  my $self = shift;
  my $amount = shift || 1;

  $self->{records_so_far} += $amount;

  if($self->{records_so_far} >
    $self->{last_reported_records} + $self->{report_interval}) {
    $self->update_metrics;
  }
}

sub labels {
  my $self = shift;
  if($self->{stage}) {
    { stage => $self->{stage} }
  } else {
    {}
  }
}

sub update_metrics {
  my $self = shift;

  $self->duration->set($self->labels, time() - $self->{start_time});
  $self->records_processed->set($self->labels, $self->{records_so_far});

  $self->push_metrics;

}

sub finalize {
  my $self = shift;

  $self->last_success->set(time());

  $self->update_metrics;
}

sub push_metrics {
  my $self = shift;

  my $job = $self->{job};
  my $url = get_config('pushgateway') . "/metrics/job/$job";
  my $data = $self->{prom}->render;

  $self->{ua}->post($url, Content => $data);

}

sub last_success {
  my $self = shift;

  $self->{last_success} ||= $self->{prom}->new_gauge(
    name => 'job_last_success',
    help => 'Last Unix time when job successfully completed',
  )
}

sub duration {
  my $self = shift;

  $self->{duration} ||= $self->{prom}->new_gauge(
    name => 'job_duration_seconds',
    help => 'Time spend running job in seconds',
    %{$self->{labels}}
  )

}

sub records_processed {
  my $self = shift;

  $self->{records_processed} ||= $self->{prom}->new_gauge(
    name => 'job_records_processed',
    help => 'Records processed by job',
    %{$self->{labels}}
  )
}

sub success_interval {
  my $self = shift;

  $self->{success_interval} ||= $self->{prom}->new_gauge(
    name => 'job_expected_success_interval',
    help => 'Maximum expected time in seconds between job completions'
  )
}

sub prometheus {
  my $self = shift;

  return $self->{prom};
}

1;
