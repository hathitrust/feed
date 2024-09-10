use strict;

use FindBin;
use lib "$FindBin::Bin/lib";

use HTFeed::Bunnies;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Queue;
use HTFeed::Test::SpecSupport qw(NO_WAIT RECV_WAIT);
use Test::Exception;
use Test::Spec;

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
	my $sql = join(
	    " ",
	    "REPLACE INTO feed_zephir_items",
	    "(namespace, id, collection, digitization_source, returned)",
	    "VALUES",
	    "(?,         ?,  'TEST',     'test',              '0')"
	);
	get_dbh()->do($sql, {}, $volume->get_namespace, $volume->get_objid);
    }

    sub testvolume {
	HTFeed::Volume->new(
	    packagetype => 'simple',
	    namespace   => 'test',
	    objid       => 'test'
	);
    }

    sub enqueue_testvolume {
	my %params = (
	    # defaults
	    volume => testvolume,
	    status => "ready",
	    # override defaults
	    @_
	);

	return HTFeed::Queue->new->enqueue(%params);
    }

    sub is_testvolume_ready {
	my $volume = testvolume;
	my $status = "ready";
	my $job    = HTFeed::Bunnies->new()->next_job(RECV_WAIT);

	is($job->{pkg_type},  $volume->get_packagetype);
	is($job->{namespace}, $volume->get_namespace);
	is($job->{id},        $volume->get_objid);
	is($job->{status},    $status);
    }

    sub get_vol_from_queue {
	my $volume = shift || testvolume;
	my $status = shift || "ready";

	my $sql = join(
	    " ",
	    "SELECT *",
	    "FROM   feed_queue",
	    "WHERE  namespace = ?",
	    "AND    id        = ?",
	    "AND    pkg_type  = ?",
	    "AND    status    = ?"
	);

	get_dbh()->selectrow_hashref(
	    $sql,
	    {},
	    $volume->get_namespace,
	    $volume->get_objid,
	    $volume->get_packagetype,
	    $status
	);
    }

    sub queue_reset {
	HTFeed::Queue->new->reset(
	    # defaults
	    volume      => testvolume,
	    reset_level => 1,
	    # override defaults
	    @_
	);
    }

    describe "enqueue" => sub {
	describe "with a new item" => sub {
	    before each => sub {
		fake_bibdata(testvolume);
	    };

	    it "returns true" => sub {
		ok(enqueue_testvolume);
	    };

	    it "puts the item in the database" => sub {
		enqueue_testvolume;
		ok(get_vol_from_queue);
	    };

	    it "puts the item in the message queue" => sub {
		enqueue_testvolume;
		is_testvolume_ready();
	    };

	    it "accepts a priority" => sub {
		my $priority = HTFeed::Queue::QUEUE_PRIORITY_MED;
		enqueue_testvolume(priority => $priority);
		my $job = HTFeed::Bunnies->new()->next_job(RECV_WAIT);
		is($job->{msg}{props}{priority}, $priority);
	    };

	    it "records the priority in the feed_queue table" => sub {
		my $priority = HTFeed::Queue::QUEUE_PRIORITY_HIGH;
		enqueue_testvolume(priority => $priority);
		is($priority, get_vol_from_queue(testvolume, 'ready')->{priority});
	    };
	};

	describe "with an item already in the queue" => sub {
	    before each => sub {
		fake_bibdata(testvolume);
		enqueue_testvolume;
	    };

	    describe "without the ignore flag" => sub {
		it "logs an error" => sub {
		    enqueue_testvolume;
		    ok($testlog->matches(qr(ERROR.*Duplicate)));
		};

		it "returns false" => sub {
		    ok(!enqueue_testvolume);
		};

		it "doesn't add a message to the message queue" => sub {
		    my $receiver = HTFeed::Bunnies->new();
		    $receiver->reset_queue;
		    enqueue_testvolume(ignore => 1);
		    ok(!$receiver->next_job(RECV_WAIT));
		}
	    };

	    describe "with the ignore flag" => sub {
		it "returns false" => sub {
		    ok(!enqueue_testvolume(ignore => 1));
		};

		it "doesn't log an error" => sub {
		    enqueue_testvolume(ignore => 1);
		    ok(!$testlog->matches(qr(ERROR)));
		};

		it "doesn't add a message to the message queue" => sub {
		    my $receiver = HTFeed::Bunnies->new();
		    $receiver->reset_queue;
		    enqueue_testvolume(ignore => 1);
		    ok(!$receiver->next_job(RECV_WAIT));
		}
	    };
	};

	describe "without bib data" => sub {
	    describe "without the no_bibdata_ok flag" => sub {
		it "logs a warning" => sub {
		    enqueue_testvolume;
		    ok($testlog->matches(qr(WARN.*bib.*data)));
		};
		it "returns false" => sub {
		    ok(!enqueue_testvolume);
		};
		it "doesn't add a message to the queue" => sub {
		    enqueue_testvolume;
		    ok(!HTFeed::Bunnies->new->next_job(RECV_WAIT));
		};
		it "doesn't put the item in the database" => sub {
		    enqueue_testvolume;
		    ok(!get_vol_from_queue);
		};
	    };

	    describe "with the no_bibdata_ok flag" => sub {
		it "returns true" => sub {
		    ok(enqueue_testvolume(no_bibdata_ok => 1));
		};
		it "puts the item in the database" => sub {
		    enqueue_testvolume(no_bibdata_ok => 1);
		    ok(get_vol_from_queue);
		};
		it "puts the item in the message queue" => sub {
		    enqueue_testvolume(no_bibdata_ok => 1);
		    is_testvolume_ready();
		};
	    };
	};

	describe "with a disallowed item" => sub {
	    before each => sub {
		fake_bibdata(testvolume);
		my $sql = join(
		    " ",
		    "INSERT INTO feed_queue_disallow",
		    "VALUES ('test', 'test', 'disallow test item', CURRENT_TIMESTAMP)"
		);
		get_dbh()->do($sql);
	    };

	    context "with default use_disallow_list" => sub {
		it "logs a warning" => sub {
		    enqueue_testvolume();
		    ok($testlog->matches(qr(WARN.*disallow)));
		};
		it "returns false" => sub {
		    ok(!enqueue_testvolume);
		};
		it "doesn't put the item in the database" => sub {
		    enqueue_testvolume;
		    ok(!get_vol_from_queue);
		};
		it "doesn't put the item in the message queue" => sub {
		    enqueue_testvolume;
		    ok(!HTFeed::Bunnies->new->next_job(RECV_WAIT));
		};
	    };

	    context "with use_disallow_list = 0" => sub {
		it "returns true" => sub {
		    ok(enqueue_testvolume(use_disallow_list => 0));
		};
		it "puts the item in the database" => sub {
		    enqueue_testvolume(use_disallow_list => 0);
		    ok(get_vol_from_queue);
		};
		it "puts the item in the message queue" => sub {
		    enqueue_testvolume(use_disallow_list => 0);
		    is_testvolume_ready();
		};
	    };
	};
    };

    describe "reset" => sub {
	before each => sub {
	    fake_bibdata(testvolume);
	};
	it "requires reset level argument" => sub {
	    enqueue_testvolume(status => 'punted');
	    throws_ok {
		HTFeed::Queue->new->reset(volume => testvolume)
	    } qr(Reset level)
	};

	describe "with reset level 1" => sub {
	    it "resets a punted volume in the database" => sub {
		enqueue_testvolume(status => 'punted');
		queue_reset;
		ok(get_vol_from_queue);
	    };
	    it "accepts a priority" => sub {
		my $priority = HTFeed::Queue::QUEUE_PRIORITY_LOW;
		enqueue_testvolume(status => 'punted');
		queue_reset(priority => $priority);
		my $job = HTFeed::Bunnies->new()->next_job(RECV_WAIT);
		is($job->{msg}{props}{priority}, $priority);
	    };

	    xit "resets the priority in the database";

            it "re-queues a message for a punted volume" => sub {
                my $receiver = HTFeed::Bunnies->new;
                enqueue_testvolume(status => 'punted');
                $receiver->reset_queue;
                queue_reset;
                is_testvolume_ready();
            };
            it "does not reset a done volume" => sub {
                enqueue_testvolume(status => 'done');
                queue_reset;
                ok(!get_vol_from_queue);
                ok(!HTFeed::Bunnies->new->next_job(RECV_WAIT));
            };

            describe "when resetting to available state" => sub {
                it "resets a punted volume" => sub {
                    enqueue_testvolume(status => 'punted');
                    queue_reset(status => 'available');
                    ok(get_vol_from_queue(testvolume, 'available'));
                };
                it "does not queue a message" => sub {
                    enqueue_testvolume(status => 'punted');
                    queue_reset(status => 'available');
                    ok(!HTFeed::Bunnies->new->next_job(RECV_WAIT));
                };
            };
        };

        describe "with reset level 2" => sub {
            it "resets a done volume in the database" => sub {
                enqueue_testvolume(status => 'done');
                queue_reset(reset_level => 2);
                ok(get_vol_from_queue);
            };
            it "re-queues a message for a done volume" => sub {
                enqueue_testvolume(status => 'done');
                HTFeed::Bunnies->new->reset_queue;
                queue_reset(reset_level => 2);
                is_testvolume_ready();
            };
            it "does not reset an in-flight volume" => sub {
                enqueue_testvolume(status => 'handled');
                HTFeed::Bunnies->new->reset_queue;
                queue_reset(reset_level => 2);
                ok(!get_vol_from_queue);
                ok(!HTFeed::Bunnies->new->next_job(RECV_WAIT));
            };
        };

        describe "with reset level 3" => sub {
            it "resets an in-flight volume in the database" => sub {
                enqueue_testvolume(status => 'handled');
                queue_reset(reset_level => 3);
                ok(get_vol_from_queue);
            };
            it "re-queues a message for an in-flight volume" => sub {
                enqueue_testvolume(status => 'handled');
                HTFeed::Bunnies->new->reset_queue;
                queue_reset(reset_level => 3);
                is_testvolume_ready();
            };
            it "updates an 'available' item to 'ready'" => sub {
                enqueue_testvolume(status => 'available');
                queue_reset(
                    reset_level => 3,
                    status      => 'ready'
                );
                ok(get_vol_from_queue);
            };
            it "queues a message when changing 'available' to 'ready'" => sub {
                enqueue_testvolume(status => 'available');
                HTFeed::Bunnies->new->reset_queue;
                queue_reset(
                    reset_level => 3,
                    status      => 'ready'
                );
                is_testvolume_ready();
            };
            it "uses the priority when initially queued when changing 'available' to 'ready'" => sub {
                my $priority = 2;
                enqueue_testvolume(
                    status   => 'available',
                    priority => $priority
                );
                HTFeed::Bunnies->new->reset_queue;
                queue_reset(
                    reset_level => 3,
                    status      => 'ready'
                );
                my $job = HTFeed::Bunnies->new()->next_job(RECV_WAIT);
                is($job->{msg}{props}{priority}, $priority);
            };
        };
    };

    describe "send_to_message_queue" => sub {
        it "with ready status, sends a message" => sub {
            HTFeed::Queue->new->send_to_message_queue(testvolume, 'ready');
            is_testvolume_ready();
        };

        it "with available status, does not send a message" => sub {
            HTFeed::Queue->new->send_to_message_queue(testvolume, 'available');
            ok(!HTFeed::Bunnies->new->next_job(RECV_WAIT));
        };
    };

};

runtests unless caller;
