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

  $self->{labels} = { };
  $self->{job} = $params{job} || $ENV{'JOB_NAME'} || basename($0);

  my $namespace =  $params{namespace} || $ENV{'JOB_NAMESPACE'};
  $self->{labels}{namespace} = $namespace if $namespace;

  my $app =  $params{app} || $ENV{'JOB_APP'};
  $self->{labels}{app} = $app if $app;

  $self->{report_interval} = $params{report_interval} || $DEFAULT_REPORT_INTERVAL;
  my $success_interval = $params{success_interval} || $ENV{'JOB_SUCCESS_INTERVAL'};

  $self->{prom} = Net::Prometheus->new(
    disable_process_collector => 1,
    disable_perl_collector => 1
  );
  $self->{ua} = LWP::UserAgent->new;

  $self->{records_so_far} = 0;
  $self->{last_reported_records} = 0;
  $self->{start_time} = time();

  $self->success_interval->set($self->{labels},$success_interval) if $success_interval;

  return $self;

}

sub label_names {
  my $self = shift;

  [keys(%{$self->{labels}})];
}

sub start_stage {
  my $self = shift;
  my $stage = shift;

  # final counts from previous stage
  $self->update_metrics if $self->{stage};

  $self->{labels}{stage} = $stage;
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

sub update_metrics {
  my $self = shift;

  $self->{last_reported_records} = $self->{records_so_far};
  $self->duration->set($self->{labels}, time() - $self->{start_time});
  $self->records_processed->set($self->{labels}, $self->{records_so_far});

  $self->push_metrics;

}

sub finalize {
  my $self = shift;

  # final metrics for this stage
  $self->update_metrics;
  
  delete $self->{labels}{stage};
  $self->last_success->set($self->{labels},time());

  $self->push_metrics;
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
    labels => $self->label_names,
  )
}

sub duration {
  my $self = shift;

  $self->{duration} ||= $self->{prom}->new_gauge(
    name => 'job_duration_seconds',
    help => 'Time spend running job in seconds',
    labels => $self->label_names,
  )

}

sub records_processed {
  my $self = shift;

  $self->{records_processed} ||= $self->{prom}->new_gauge(
    name => 'job_records_processed',
    help => 'Records processed by job',
    labels => $self->label_names,
  )
}

sub success_interval {
  my $self = shift;

  $self->{success_interval} ||= $self->{prom}->new_gauge(
    name => 'job_expected_success_interval',
    help => 'Maximum expected time in seconds between job completions',
    labels => $self->label_names,
  )
}

sub prometheus {
  my $self = shift;

  return $self->{prom};
}

1;
