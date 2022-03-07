use FindBin;
use lib "$FindBin::Bin/lib";
use Test::Spec;
use Test::Exception;
use HTFeed::Test::SpecSupport;

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Bunnies;
use HTFeed::Queue;

use strict;

my $NO_WAIT = -1;

describe "HTFeed::Queue" => sub {
  my $testlog;

  before all => sub {
    $testlog = HTFeed::Test::Logger->new();
  };

  before each => sub {
    HTFeed::Bunnies->new()->reset_queue;
    get_dbh()->do("DELETE FROM feed_queue");
    get_dbh()->do("DELETE FROM feed_zephir_items");
    get_dbh()->do("DELETE FROM feed_queue_disallow");
    $testlog->reset;
  };

  sub fake_bibdata {
    my $volume = shift;

    get_dbh()->do("REPLACE INTO feed_zephir_items (namespace, id, collection, digitization_source, returned) values (?,?,'TEST','test','0')",{},$volume->get_namespace,$volume->get_objid);
  }
  
  sub testvolume {
    HTFeed::Volume->new(packagetype => 'simple', 
      namespace => 'test', 
      objid => 'test');
  }

  sub test_job_queued_for_volume {
    my $volume = shift;
    my $status = shift;

    my $job = HTFeed::Bunnies->new()->next_job($NO_WAIT);
    is($job->{pkg_type},  $volume->get_packagetype);
    is($job->{namespace}, $volume->get_namespace);
    is($job->{id},        $volume->get_objid);
    is($job->{status},    $status);
  }

  sub volume_in_feed_queue {
    my $volume = shift;
    my $status = shift;

    get_dbh()->selectrow_hashref("SELECT * FROM feed_queue WHERE namespace = ? and id = ? and pkg_type = ? and status = ?",{},$volume->get_namespace,$volume->get_objid,$volume->get_packagetype,$status);

  }

  describe "enqueue" => sub {
    describe "with a new item with ready status" => sub {
      before each => sub { fake_bibdata(testvolume); };

      it "returns true" => sub {
        ok(HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready'));
      };

      it "puts the item in the database" => sub {
        HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready');

        ok(volume_in_feed_queue(testvolume, 'ready'));
      };
      
      it "puts the item in the message queue" => sub {
        HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready');

        test_job_queued_for_volume(testvolume, 'ready');
      };
    };

    describe "with an item already in the queue" => sub {
      before each => sub { 
        fake_bibdata(testvolume);
        HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready');
      };

      describe "without the ignore flag" => sub {

        it "logs an error" => sub {
          HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready');
          ok($testlog->matches(qr(ERROR.*Duplicate)));
        };

        it "returns false" => sub {
          ok(! HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready'));
        };

        it "doesn't add a message to the message queue" => sub {
          my $receiver = HTFeed::Bunnies->new();
          $receiver->reset_queue;

          HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready', ignore => 1);
          ok(!$receiver->next_job($NO_WAIT));

        }
      };

      describe "with the ignore flag" => sub {
        it "returns false" => sub {
          ok(! HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready', ignore => 1));
        };

        it "doesn't log an error" => sub {
          HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready', ignore => 1);
          ok(!$testlog->matches(qr(ERROR)));
        };

        it "doesn't add a message to the message queue" => sub {
          my $receiver = HTFeed::Bunnies->new();
          $receiver->reset_queue;

          HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready', ignore => 1);
          ok(!$receiver->next_job($NO_WAIT));

        }
      };
    };

    describe "without bib data" => sub {
      describe "without the no_bibdata_ok flag" => sub {
        it "logs a warning" => sub {
          HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready');

          ok($testlog->matches(qr(WARN.*bib.*data)));
        };

        it "returns false" => sub {
          ok(!HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready'));
        };
        
        it "doesn't add a message to the queue" => sub {
          HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready');

          ok(!HTFeed::Bunnies->new->next_job($NO_WAIT));
        };
        it "doesn't put the item in the database" => sub {
          HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready');

          ok(!volume_in_feed_queue(testvolume, 'ready'));
        };
      };

      describe "with the no_bibdata_ok flag" => sub {
        it "returns true" => sub {
          ok(HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready', no_bibdata_ok=>1));
        };
        it "puts the item in the database" => sub {
          HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready', no_bibdata_ok=>1);

          ok(volume_in_feed_queue(testvolume, 'ready'));
        };
        
        it "puts the item in the message queue" => sub {
          HTFeed::Queue->new->enqueue(volume => testvolume, status => 'ready', no_bibdata_ok=>1);
 
          test_job_queued_for_volume(testvolume, 'ready');
        };
      };
    };

    describe "with a disallowed item" => sub {
      before each => sub {
        fake_bibdata(testvolume);
        get_dbh()->do("INSERT INTO feed_queue_disallow VALUES ('test','test','disallow test item',CURRENT_TIMESTAMP)");
      };

      context "with default use_disallow_list" => sub {
        it "logs a warning" => sub {
          HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready');

          ok($testlog->matches(qr(WARN.*disallow)));
        };

        it "returns false" => sub {
          ok(!HTFeed::Queue->new->enqueue(volume=>testvolume, status => 'ready'));
        };

        it "doesn't put the item in the database" => sub {
          HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready');

          ok(!volume_in_feed_queue(testvolume, 'ready'));
        };

        it "doesn't put the item in the message queue" => sub {
          HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready');
          
          ok(!HTFeed::Bunnies->new->next_job($NO_WAIT));
        };
      };

      context "with use_disallow_list = 0" => sub {
        it "returns true" => sub {
          ok(HTFeed::Queue->new->enqueue(volume=>testvolume, status => 'ready', use_disallow_list => 0));
        };

        it "puts the item in the database" => sub {
          HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready', use_disallow_list => 0);

          ok(volume_in_feed_queue(testvolume, 'ready'));
        };

        it "puts the item in the message queue" => sub {
          HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'ready', use_disallow_list => 0);
          
          test_job_queued_for_volume(testvolume,'ready');
        };
      };
    };
  };

  describe "reset" => sub {
    before each => sub {
      fake_bibdata(testvolume);
    };

    it "requires reset level argument" => sub {
      HTFeed::Queue->new->enqueue(volume=>testvolume, status=>'punted');
      throws_ok { HTFeed::Queue->new->reset(volume => testvolume) } qr(Reset level)
    };

    describe "with reset level 1" => sub {
      it "resets a punted volume in the database" => sub {
        my $queue = HTFeed::Queue->new;
        $queue->enqueue(volume=>testvolume, status=>'punted');
        $queue->reset(volume=>testvolume, reset_level => 1);
        ok(volume_in_feed_queue(testvolume, 'ready'));
      };

      it "re-queues a message for a punted volume" => sub {
        my $queue = HTFeed::Queue->new;
        my $receiver = HTFeed::Bunnies->new;
        $queue->enqueue(volume=>testvolume, status=>'punted');
        $receiver->reset_queue;
        
        $queue->reset(volume=>testvolume, reset_level => 1);
        test_job_queued_for_volume(testvolume,'ready');
      };

      it "does not reset a done volume" => sub {
        my $queue = HTFeed::Queue->new;
        $queue->enqueue(volume=>testvolume, status=>'done');
        $queue->reset(volume=>testvolume, reset_level => 1);
        ok(!volume_in_feed_queue(testvolume, 'ready'));
        ok(!HTFeed::Bunnies->new->next_job($NO_WAIT));
      };

      describe "when resetting to available state" => sub {
        it "resets a punted volume" => sub {
          my $queue = HTFeed::Queue->new;
          $queue->enqueue(volume=>testvolume, status=>'punted');
          $queue->reset(volume=>testvolume, reset_level => 1, status=>'available');
          ok(volume_in_feed_queue(testvolume, 'available'));
        };

        it "does not queue a message" => sub {
          my $queue = HTFeed::Queue->new;
          $queue->enqueue(volume=>testvolume, status=>'punted');
          $queue->reset(volume=>testvolume, reset_level => 1, status=>'available');
          ok(!HTFeed::Bunnies->new->next_job($NO_WAIT));
        };
      };
    };

    describe "with reset level 2" => sub {
      it "resets a done volume in the database" => sub {
        my $queue = HTFeed::Queue->new;
        $queue->enqueue(volume=>testvolume, status=>'done');
        $queue->reset(volume=>testvolume, reset_level => 2);
        ok(volume_in_feed_queue(testvolume, 'ready'));
      };

      it "re-queues a message for a done volume" => sub {
        my $queue = HTFeed::Queue->new;
        $queue->enqueue(volume=>testvolume, status=>'done');
        HTFeed::Bunnies->new->reset_queue;
        
        $queue->reset(volume=>testvolume, reset_level => 2);
        test_job_queued_for_volume(testvolume,'ready');
      };

      it "does not reset an in-flight volume" => sub {
        my $queue = HTFeed::Queue->new;
        $queue->enqueue(volume=>testvolume, status=>'handled');
        HTFeed::Bunnies->new->reset_queue;

        $queue->reset(volume=>testvolume, reset_level => 2);
        ok(!volume_in_feed_queue(testvolume, 'ready'));
        ok(!HTFeed::Bunnies->new->next_job($NO_WAIT));
      };
    };

    describe "with reset level 3" => sub {
      it "resets an in-flight volume in the database" => sub {
        my $queue = HTFeed::Queue->new;
        $queue->enqueue(volume=>testvolume, status=>'handled');
        $queue->reset(volume=>testvolume, reset_level => 3);
        ok(volume_in_feed_queue(testvolume, 'ready'));
      };

      it "re-queues a message for an in-flight volume" => sub {
        my $queue = HTFeed::Queue->new;
        $queue->enqueue(volume=>testvolume, status=>'handled');
        HTFeed::Bunnies->new->reset_queue;
        
        $queue->reset(volume=>testvolume, reset_level => 3);
        test_job_queued_for_volume(testvolume,'ready');
      };

      it "updates an 'available' item to 'ready'" => sub {
        my $queue = HTFeed::Queue->new;
        $queue->enqueue(volume=>testvolume, status=>'available');
        $queue->reset(volume=>testvolume, reset_level => 3, status => 'ready');
        ok(volume_in_feed_queue(testvolume, 'ready'));
      };

      it "queues a message when changing 'available' to 'ready'" => sub {
        my $queue = HTFeed::Queue->new;
        $queue->enqueue(volume=>testvolume, status=>'available');
        HTFeed::Bunnies->new->reset_queue;
        
        $queue->reset(volume=>testvolume, reset_level => 3, status => 'ready');
        test_job_queued_for_volume(testvolume,'ready');
      };
    };

  };

  describe "send_to_message_queue" => sub {
    
    it "with ready status, sends a message" => sub {
      HTFeed::Queue->new->send_to_message_queue(testvolume,'ready');
      test_job_queued_for_volume(testvolume,'ready');
    };

    it "with available status, does not send a message" => sub {
      HTFeed::Queue->new->send_to_message_queue(testvolume,'available');
      ok(!HTFeed::Bunnies->new->next_job($NO_WAIT));
    };
  };

};

runtests unless caller;
