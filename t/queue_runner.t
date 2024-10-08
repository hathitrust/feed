use FindBin;
use lib "$FindBin::Bin/lib";
use Test::Spec;
use Test::Exception;
use HTFeed::Test::SpecSupport qw(mock_zephir NO_WAIT RECV_WAIT);
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Config qw(get_config set_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Bunnies;
use HTFeed::Queue;
use HTFeed::QueueRunner;

use strict;

describe "HTFeed::QueueRunner" => sub {
    local our ($tmpdirs, $testlog);
    my $old_storage_classes;

    sub testvolume {
        my $objid = shift;

        HTFeed::Volume->new(
            packagetype => 'simple',
            namespace   => 'test',
            objid       => $objid
        );
    }

    sub queue_test_item {
        my $objid = shift;

        my $volume = testvolume($objid);
        # put SIP in place to bypass download
        system("mkdir", $tmpdirs->{fetch}. "/test");
        system(
            "cp",
            $tmpdirs->test_home . "/fixtures/simple/test/$objid.zip",
            $tmpdirs->{fetch}   . "/test"
        );
        HTFeed::Queue->new()->enqueue(
            volume        => $volume,
            no_bibdata_ok => 1
        );
    }

    sub queue_bad_job {
        # Directly insert data to database & rabbitmq to test what happens when we
        # get something we can't handle
        my ($namespace, $objid, $pkgtype, $status) = @_;

        HTFeed::Bunnies->new->queue_job(
            namespace => $namespace,
            id        => $objid,
            pkg_type  => $pkgtype,
            status    => $status
        );

        get_dbh()->do(
            "INSERT INTO feed_queue (namespace, id, pkg_type, status) VALUES (?,?,?,?)",
            {},
            $namespace,
            $objid,
            $pkgtype,
            $status
        );
    }

    sub no_messages_in_queue {
        not defined HTFeed::Bunnies->new()->next_job(NO_WAIT);
    }

    sub queue_runner {
        HTFeed::QueueRunner->new(timeout => RECV_WAIT, should_fork => 0, clean => 0);
    }

    sub feed_queue_has_row {
        my ($namespace, $objid, $pkgtype, $status) = @_;

        get_dbh()->selectrow_hashref(
            "SELECT * FROM feed_queue WHERE namespace = ? and id = ? and pkg_type = ? and status = ?",
            {},
            $namespace,
            $objid,
            $pkgtype,
            $status
        );
    }

    sub volume_in_feed_queue {
        my $volume = shift;
        my $status = shift;

        feed_queue_has_row(
            $volume->get_namespace,
            $volume->get_objid,
            $volume->get_packagetype,
            $status
        );
    }

    before all => sub {
        load_db_fixtures;
        mock_zephir;
        $tmpdirs = HTFeed::Test::TempDirs->new();
        $testlog = HTFeed::Test::Logger->new();
        set_config(0, 'stop_on_error');
        queue_runner->{job_metrics}->clear;
    };

    before each => sub {
        $tmpdirs->setup_example;
        $testlog->reset;
        HTFeed::Bunnies->new()->reset_queue;
        get_dbh()->do("DELETE FROM feed_queue");
        $old_storage_classes = get_config('storage_classes');
        my $new_storage_classes = {
            'localpairtree-test' => {
                class   => 'HTFeed::Storage::LocalPairtree',
                obj_dir => $tmpdirs->{obj_dir},
            },
        };
        set_config($new_storage_classes, 'storage_classes');
    };

    after each => sub {
        $tmpdirs->cleanup_example;
        set_config($old_storage_classes, 'storage_classes');
    };

    after all => sub {
        $tmpdirs->cleanup;
    };

    it "ingests an enqueued item" => sub {
        queue_test_item('ok');
        queue_runner->run();
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/ok/ok/ok.zip",      'puts the zip in the repository');
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/ok/ok/ok.mets.xml", 'puts the METS in the repository');
    };

    it "reports success to the database" => sub {
        queue_test_item('ok');
        queue_runner->run();
        ok(volume_in_feed_queue(testvolume('ok'), 'collated'));
    };

    it "does some roundabout jobmetrics integration testing" => sub {
        # Same test as the one above, except with the addition of testing
        # that it increments $metric. First clear the metrics.
        my $pack_bytes_metric = "ingest_pack_bytes_r_total";
        my $collate_metric    = "ingest_collate_items_total";
        my $jm                = queue_runner->{job_metrics};
        $jm->clear;
        ok($jm->get_value($collate_metric) == 0);
        # Run the test and expect the metric to increment
        queue_test_item('ok');
        queue_runner->run();
        ok(volume_in_feed_queue(testvolume('ok'), 'collated'));
        ok($jm->get_value($collate_metric) == 1);
        # Also check that at least 5 time-based metrics were incremented
        my $timebased_metrics = $jm->match('^ingest_.+_seconds_total');
        ok(scalar(@$timebased_metrics) > 5);
        # Also check that HTFeed::Stage::Pack incremented bytes
        # (it's the only stage implementing bytes so far)
        ok($jm->get_value($pack_bytes_metric) > 1); # i.e. has counted SOME bytes
    };

    xit "acks the message on success" => sub {
        queue_test_item('ok');
        queue_runner->run();

        ok(no_messages_in_queue);
    };

    xit "reports failure to the database" => sub {
        queue_test_item('bad_meta_yml');
        queue_runner->run();

        ok(volume_in_feed_queue(testvolume('bad_meta_yml'), 'punted'));
    };

    xit "acks the message on failure" => sub {
        queue_test_item('bad_meta_yml');
        queue_runner->run();

        ok(no_messages_in_queue);
    };

    xit "reports failure with a job with no namespace/objid" => sub {
        HTFeed::Bunnies->new->queue_job(data => 'garbage');

        queue_runner->run();

        ok($testlog->matches(qr(Missing job fields)));
        ok(no_messages_in_queue);
    };

    xit "reports failure with a job with unknown state" => sub {
        queue_bad_job('test', 'test', 'simple', 'unknown');

        queue_runner->run();

        ok(volume_in_feed_queue(testvolume('test'), 'punted'));
        ok($testlog->matches(qr(stage unknown not defined)));
        ok(no_messages_in_queue);
    };

    xit "reports failure with a job with an unknown namespace" => sub {
        queue_bad_job('unknown', 'test', 'simple', 'ready');

        queue_runner->run();

        ok(feed_queue_has_row('unknown', 'test', 'simple', 'punted'));
        ok($testlog->matches(qr(unknown.*namespace.*unknown)i));
        ok(no_messages_in_queue);
    };

    xit "reports failure with a job with an invalid id" => sub {
        queue_bad_job('test', 'invalid', 'simple', 'ready');

        queue_runner->run();

        ok(feed_queue_has_row('test', 'invalid', 'simple', 'punted'));
        ok($testlog->matches(qr(invalid barcode)i));
        ok(no_messages_in_queue);
    };

    xit "reports failure with a job with an unknown package type" => sub {
        queue_bad_job('test', 'test', 'unknown', 'ready');

        queue_runner->run();

        ok(feed_queue_has_row('test', 'test', 'unknown', 'punted'));
        ok($testlog->matches(qr(invalid packagetype)i));
        ok(no_messages_in_queue);
    };

    # TODO: how to simulate this?
    xit "gets the job again on unexpected failure";

    # TODO: how to simulate this?
    xit "does the appropriate thing on SIGINT/SIGTERM";

};

runtests unless caller;
