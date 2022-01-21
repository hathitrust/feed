use FindBin;
use lib "$FindBin::Bin/lib";
use Test::Spec;
use JSON::XS qw(decode_json);
use HTFeed::Test::SpecSupport;
use HTFeed::Config qw(get_config);
use HTFeed::Bunnies;
use utf8;

use strict;

# before each connect & clear queue

describe "HTFeed::Bunnies" => sub {
  my $NO_WAIT = -1;
  sub bunnies {
    HTFeed::Bunnies->new();
  }

  before each => sub {
    bunnies->reset_queue;
  };

  describe '#new' => sub {
    it "can be constructed" => sub {
      ok(bunnies);
    };
  };

  describe "#queue_job" => sub {
    it "puts a message on the configured queue that we can fetch" => sub {
      my $bunnies = bunnies;
      $bunnies->queue_job();
      ok($bunnies->{mq}->get($bunnies->{channel},$bunnies->{queue}));
    };

    it "serializes a hash as json for the message" => sub {
      my $bunnies = bunnies;
      my %params = (param1 => "value1", param2 => "value2");
      $bunnies->queue_job(%params);
      my $msg = $bunnies->{mq}->get($bunnies->{channel},$bunnies->{queue});
      is_deeply(decode_json($msg->{body}),\%params);

    };
  };

  describe "#next_job" => sub {
    it "gets the previously-queued job" => sub {
      bunnies->queue_job();
      ok(bunnies->next_job($NO_WAIT));
    };

    it "returns the given parameters" => sub {
      my %params = (param1 => "value1", param2 => "value2");
      bunnies->queue_job(%params);
      my $job_info = bunnies->next_job($NO_WAIT);
      is($job_info->{param1}, "value1");
      is($job_info->{param2}, "value2");
    };

    it "saves a reference to the message" => sub {
      bunnies->queue_job();
      my $job_info = bunnies->next_job($NO_WAIT);
      ok($job_info->{msg});
    };

  };

  describe "retry" => sub {
    it "does not get the same job again if the job was finished" => sub {
      bunnies->queue_job;

      my $receiver = bunnies;
      my $job = $receiver->next_job($NO_WAIT);
      $receiver->finish($job);
      # ensure channel is closed
      $receiver->{mq}->disconnect();

      ok(not defined bunnies->next_job($NO_WAIT));

    };

    it "after reconnect, gets the same job again if job wasn't finished" => sub {
      bunnies->queue_job;
      # consume, don't ack, reset & try again; should get it again
      bunnies->next_job($NO_WAIT);
      ok(bunnies->next_job($NO_WAIT));
    };

    it "on the same connection, does not deliver another job if previous job wasn't acked" => sub {
      my $queuer = bunnies;
      $queuer->queue_job;
      $queuer->queue_job;
      
      my $receiver = bunnies;
      $receiver->next_job($NO_WAIT);
      ok(not defined $receiver->next_job($NO_WAIT));
    };
  }
};

runtests unless caller;
