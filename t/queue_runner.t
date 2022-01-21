use FindBin;
use lib "$FindBin::Bin/lib";
use Test::Spec;
use Test::Exception;
use HTFeed::Test::SpecSupport qw(mock_zephir);
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Config qw(get_config set_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Bunnies;
use HTFeed::Queue;
use HTFeed::QueueRunner;

use strict;

my $NO_WAIT = -1;

describe "HTFeed::QueueRunner" => sub {
  local our ($tmpdirs, $testlog);
  my $old_storage_classes;

  sub testvolume {
    my $objid = shift;
    HTFeed::Volume->new(packagetype => 'simple', 
      namespace => 'test', 
      objid => $objid);
  }

  sub queue_test_item {
    my $objid = shift;
    my $volume = testvolume($objid);
    # put SIP in place to bypass download
    system("mkdir",$tmpdirs->{fetch}. "/test");
    system("cp",$tmpdirs->test_home . "/fixtures/simple/test/$objid.zip",$tmpdirs->{fetch} . "/test");
    HTFeed::Queue->new()->enqueue(volume => $volume, no_bibdata_ok => 1);
  }

  sub volume_in_feed_queue {
    my $volume = shift;
    my $status = shift;

    get_dbh()->selectrow_hashref("SELECT * FROM feed_queue WHERE namespace = ? and id = ? and pkg_type = ? and status = ?",{},$volume->get_namespace,$volume->get_objid,$volume->get_packagetype,$status);

  }

  sub queue_runner {
    HTFeed::QueueRunner->new(timeout => $NO_WAIT, should_fork => 0, clean => 0);
  }

  before all => sub {
    load_db_fixtures;
    mock_zephir;
    $tmpdirs = HTFeed::Test::TempDirs->new();
    $testlog = HTFeed::Test::Logger->new();
    set_config(0,'stop_on_error');
  };

  before each => sub {
    $tmpdirs->setup_example;
    $testlog->reset;
    HTFeed::Bunnies->new()->reset_queue;
    get_dbh()->do("DELETE FROM feed_queue");
    $old_storage_classes = get_config('storage_classes');
    my $new_storage_classes = {
      'localpairtree-test' =>
      {
        class => 'HTFeed::Storage::LocalPairtree',
        obj_dir => $tmpdirs->{obj_dir},
      },
    };
    set_config($new_storage_classes,'storage_classes');
  };

  after each => sub {
    $tmpdirs->cleanup_example;
    set_config($old_storage_classes,'storage_classes');
  };

  after all => sub {
    $tmpdirs->cleanup;
  };

  it "ingests an enqueued item" => sub {
    queue_test_item('ok');
    queue_runner->run();
    ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/ok/ok/ok.zip",'puts the zip in the repository');
    ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/ok/ok/ok.mets.xml",'puts the METS in the repository');
  };

  # XXX: whose responsibility is this? Probably the job, not really the queue runner..
  it "updates the status in the database for each job";
  
  it "reports success to the database" => sub {
    queue_test_item('ok');
    queue_runner->run();
    volume_in_feed_queue(testvolume('ok'),'collated');
  };

  it "acks the message on success" => sub {
    queue_test_item('ok');
    queue_runner->run();

    # job should have been acked, so message should not be re-delivered
    ok(not defined HTFeed::Bunnies->new()->next_job($NO_WAIT));
  };

  it "reports failure to the database" => sub {
    queue_test_item('bad_meta_yml');
    queue_runner->run();

    volume_in_feed_queue(testvolume('bad_meta_yml'),'punted');
  };

  it "acks the message on failure" => sub {
    queue_test_item('bad_meta_yml');
    queue_runner->run();

    # job should still be acked on failure; no separate 'failure queue' in
    # rabbitmq
    ok(not defined HTFeed::Bunnies->new()->next_job($NO_WAIT));
  };

  # TODO: how to simulate this?
  it "gets the job again on unexpected failure";

  # TODO: how to simulate this?
  it "does the appropriate thing on SIGINT/SIGTERM";

};

runtests unless caller;
