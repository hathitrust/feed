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
  my %params = @;


  my $self = bless {}, $class;

  $self->{job} = $params->{job} || $ENV{'JOB_NAME'} || basename($0);
  $self->{report_interval} = $params->{report_interval} || $DEFAULT_REPORT_INTERVAL;
  my $success_interval = $params->{success_interval} || $ENV{'JOB_SUCCESS_INTERVAL'};

  $self->{job} = $job;
  $self->{prom} = Net::Prometheus->new;
  $self->{ua} = LWP::UserAgent->new;

  $self->{records_so_far} = {};
  $self->{last_reported_records} = {};
  $self->{start_time} = time();

  if($success_interval) { 
    $self->success_interval->set($success_interval);
  }

  $self->update_metrics;

  return $self;

}

sub inc {
  my $self = shift;
  my $label = shift || "";
  my $amount = shift || 1;

  $self->{records_so_far}{$label} += $amount;

  if($self->{records_so_far}{$label} > 
    $self->{last_reported_records}{$label} + $self->{report_interval}) {
    $self->update_metrics;
  }
}

sub update_metrics {
  my $self = shift;

  $self->duration->set(time() - $self->{start_time});

  while(my ($label, $value) = each(%{$self->{records_so_far}})) { 
    $self->records_processed->set({ stage => $label }, $value);
    $self->{last_reported_records}{$label} = $value;
  }

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
