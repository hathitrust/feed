use Test::Spec;
use Test::Time;
use HTFeed::Config qw(get_config);
use HTFeed::ProgressTracker;
use LWP::UserAgent;

use strict;

describe "HTFeed::ProgressTracker" => sub {

  sub pushgateway { get_config('pushgateway') }

  sub metrics {
    LWP::UserAgent->new
      ->request(HTTP::Request->new(GET => pushgateway . '/metrics'))
      ->decoded_content;
  }

  before each => sub {
    delete $ENV{JOB_NAME};
    delete $ENV{JOB_SUCCESS_INTERVAl};
    delete $ENV{JOB_NAMESPACE};
    delete $ENV{JOB_APP};

    LWP::UserAgent->new
      ->request(HTTP::Request->new(PUT => pushgateway . '/api/v1/admin/wipe'));
  };

  it "can be constructed" => sub {
    my $tracker = HTFeed::ProgressTracker->new();

    ok($tracker);
  };

  describe "job name" => sub {
    it "uses name of script by default" => sub {
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;

      ok(metrics =~ /^job_duration_seconds\{instance="",job="pushgateway.t"\}/m);
    };

    it "uses JOB_NAME env var if given" => sub {
      $ENV{JOB_NAME} = 'some-job-name';

      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;

      ok(metrics =~ /^job_duration_seconds\{instance="",job="some-job-name"\}/m);
      ok(metrics !~ /^job_duration_seconds\{instance="",job="pushgateway.t"\}/m);
    };

    it "uses job name parameter if given" => sub {
      $ENV{JOB_NAME} = 'some-job-name';

      my $tracker = HTFeed::ProgressTracker->new(job => 'override-job-name');
      $tracker->update_metrics;

      ok(metrics !~ /^job_duration_seconds\{instance="",job="pushgateway.t"\}/m);
      ok(metrics !~ /^job_duration_seconds\{instance="",job="some-job-name"\}/m);
      ok(metrics =~ /^job_duration_seconds\{instance="",job="override-job-name"\}/m);
    }
  };

  describe "namespace label" => sub {
    it "has no namespace label by default" => sub {
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;

      ok(metrics !~ /^job_duration_seconds.*namespace=/m);
    };

    it "uses namespace param if given" => sub {
      $ENV{JOB_NAMESPACE} = 'some-namespace';
      my $tracker = HTFeed::ProgressTracker->new(namespace=>'override-namespace');
      $tracker->update_metrics;

      ok(metrics =~ /^job_duration_seconds\S*namespace="override-namespace"/m);
    };

    it "uses JOB_NAMESPACE env var if given" => sub {
      $ENV{JOB_NAMESPACE} = 'some-namespace';
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;

      ok(metrics =~ /^job_duration_seconds\S*namespace="some-namespace"/m);
    };
  };

  describe "app label" => sub {
    it "has no app label by default" => sub {
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;

      ok(metrics !~ /^job_duration_seconds.*app=/m);
    };

    it "uses app param if given" => sub {
      $ENV{JOB_APP} = 'some-app';
      my $tracker = HTFeed::ProgressTracker->new(app=>'override-app');
      $tracker->update_metrics;

      ok(metrics =~ /^job_duration_seconds\S*app="override-app"/m);
    };

    it "uses JOB_APP env var if given" => sub {
      $ENV{JOB_APP} = 'some-app';
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;

      ok(metrics =~ /^job_duration_seconds\S*app="some-app"/m);
    };
  };

  describe "job_expected_success_interval metric" => sub {
    it "does not push by default" => sub {
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;

      ok(metrics !~ /^job_expected_success_interval/m);
    };

    it "uses JOB_SUCCESS_INTERVAL env var" => sub {
      $ENV{JOB_SUCCESS_INTERVAL} = '12345';
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;

      ok(metrics =~ /^job_expected_success_interval\S* 12345$/m);
    };

    it "uses success interval parameter" => sub {
      $ENV{JOB_SUCCESS_INTERVAL} = '12345';
      my $tracker = HTFeed::ProgressTracker->new(success_interval => 67890);
      $tracker->update_metrics;

      ok(metrics !~ /^job_expected_success_interval\S* 12345$/m);
      ok(metrics =~ /^job_expected_success_interval\S* 67890$/m);
    };

    it "works if there is a namespace label" => sub {
      $ENV{JOB_SUCCESS_INTERVAL} = '12345';
      $ENV{JOB_NAMESPACE} = 'some-namespace';
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;

      ok(metrics =~ /^job_expected_success_interval\S*namespace="some-namespace"\S* 12345$/m);
    };
  };

  describe "push_metrics" => sub {
    it "updates duration" => sub { 
      # Test::Time overrides to freeze apparent time
      my $now = time();
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;
      ok(metrics =~ /^job_duration_seconds\S+ 0$/m);
      # Test::Time overrides to change apparent time
      sleep(20);
      $tracker->update_metrics;
      ok(metrics =~ /^job_duration_seconds\S+ 20$/m);
    };

    it "updates records processed" => sub {
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;
      ok(metrics =~ /^job_records_processed\S+ 0$/m);
      $tracker->inc(1234);
      ok(metrics =~ /^job_records_processed\S+ 1234$/m);
    };

    it "does not push last success time without finalize" => sub {
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;
      ok(metrics !~ /^job_last_success/m);
    };

  };

  context "without stage" => sub {
    it "does not use a stage label for record count" => sub {
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;
      ok(metrics !~ /^job_records_processed.*stage/m);
    };

    it "does not use a stage label for duration" => sub {
      my $tracker = HTFeed::ProgressTracker->new();
      $tracker->update_metrics;
      ok(metrics !~ /^job_duration_seconds.*stage/m);
    };
  };

  context "with stages" => sub {
    it "uses a stage label for record count" => sub {
      my $tracker = HTFeed::ProgressTracker->new();

      $tracker->start_stage("new_stage");
      $tracker->inc(1234);
      $tracker->update_metrics;

      ok(metrics =~ /^job_records_processed\S*stage="new_stage"\S* 1234$/m);
    };

    it "uses a stage label for duration" => sub {
      my $tracker = HTFeed::ProgressTracker->new();

      $tracker->start_stage("new_stage");
      # Test::Time overrides to change apparent time
      sleep(300);
      $tracker->update_metrics;
      ok(metrics =~ /^job_duration_seconds\S*stage="new_stage"\S* 300$/m);
    };

    it "resets record count and time for new stage" => sub {
      my $tracker = HTFeed::ProgressTracker->new();

      $tracker->start_stage("old_stage");
      $tracker->inc(1234);
      # Test::Time overrides to change apparent time
      sleep(300);
      $tracker->start_stage("new_stage");

      ok(metrics =~ /^job_records_processed\S*stage="new_stage"\S* 0$/m);
      ok(metrics =~ /^job_duration_seconds\S*stage="new_stage"\S* 0$/m);
    }
  };

  describe "#finalize" => sub {
    it "updates last success time" => sub {
      my $tracker = HTFeed::ProgressTracker->new();
      # Test::Time overrides to freeze apparent time
      my $now = time();

      $tracker->finalize;
      # Metric may be formatted as e.g. 1.638994312e+09 but this should still
      # compare ==
      ok(metrics =~ /^job_last_success\S* (\S+)/m);
      ok($1 == $now);

    };
  };

  describe "#inc" => sub {
    it "pushes when record count exceeds report interval" => sub {
      my $tracker = HTFeed::ProgressTracker->new(report_interval => 10);

      $tracker->inc(15);
      ok(metrics =~ /^job_records_processed\S* 15$/m);

      # Only processed one more record, shouldn't push
      $tracker->inc();
      ok(metrics =~ /^job_records_processed\S* 15$/m);

      # Crossed the threshold; should push
      $tracker->inc(14);
      ok(metrics =~ /^job_records_processed\S* 30$/m);
    };
  };

};

runtests unless caller;
