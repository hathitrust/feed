use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Queue;
use HTFeed::Volume;
use Test::Exception;
use Test::Spec;

describe "bin/enqueue.pl" => sub {

    sub testvolume {
	HTFeed::Volume->new(
	    packagetype => 'simple',
	    namespace   => 'test',
	    objid       => 'test'
	);
    }

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

    # Run a commandline invocation and check output against provided rx
    sub enqueue {
        my $cmd                = shift;
        my $match_rx           = shift;
        my $expect_match_count = shift;
	my $verbose            = shift || 0;

        my $full_cmd = "perl bin/enqueue.pl $cmd";
	my (undef, undef, $line) = caller;
        print "Check output from command on line $line [$full_cmd] against rx [$match_rx]\n" if $verbose;

        # Run command, capture output.
	# Use double spaces to make it look good.
        my @cmd_output = `$full_cmd`;
	my $double_space = "  ";
        print "Output:[\n$double_space" . join($double_space, @cmd_output) . "]\n" if $verbose;

        # Check that the desired regex was found in the output
        my $match_count = grep {$_ =~ $match_rx} @cmd_output;
        print "Expected $match_rx match count: $expect_match_count, got $match_count\n" if $verbose;
        ok($match_count == $expect_match_count);
	print "\n" if $verbose;
    }

    before each => sub {
        HTFeed::Bunnies->new()->reset_queue;
        get_dbh()->do("DELETE FROM feed_queue");
        get_dbh()->do("DELETE FROM feed_zephir_items");
    };

    it "won't queue if missing bib data" => sub {
        enqueue(
            '-v -i -1 simple test test',
            qr/Missing bibliographic data/,
            1
        );
    };
    it "can queue if there is bib data" => sub {
	fake_bibdata(testvolume);
        enqueue(
            '-v -i -1 simple test test',
            qr/simple test test: queued/,
            1
        );
    };
    it "won't queue an item already in the queue using -i" => sub {
	fake_bibdata(testvolume);
	my $same_command = '-v -i -1 simple test test';
        enqueue(
            $same_command,
            qr/simple test test: queued/,
            1
        );
        enqueue(
            $same_command,
            qr/simple test test: failure or skipped/,
            1
        );
    };
    it "needs -r or -R to queue an item already in the queue" => sub {
	fake_bibdata(testvolume);
        enqueue_testvolume(status => 'punted');

        # Need to specify -r or -R for it to work
        enqueue(
            '-v -r -1 simple test test',
            qr/simple test test: reset/,
            1
        );
        enqueue(
            '-v -R -1 simple test test',
            qr/simple test test: reset/,
            1
        );
    };
    it "uses -u to reuse punted items rather than re-download" => sub {
	fake_bibdata(testvolume);
	enqueue_testvolume(status => 'punted');

	# -u to reuse a punted item,
	# only works in combination with a reset flag (-r/-R).
	# (in this case i'm also re-routing stderr to devnull,
	# because i'm doing such a bad thing that enqueue.pl
	# is going to print its whole pod2usage to stderr, and I don't want it)
	enqueue(
            '-v -u -1 simple test test 2>/dev/null',
            qr/empty result/,
            0
        );

	# This time with both -r and -u,
	# but since things haven't run normally
	# it won't find anything in the failed location
	enqueue(
            '-v -r -u -1 simple test test',
            qr/can't find sip in ingest or failure location/,
            1
        );

	# Make the failed location and put a volume there,
	# and this time the punted item will be reused.
	system("mkdir -p /tmp/prep/failed/test/");
	system("cp /usr/local/feed/t/fixtures/volumes/test.zip /tmp/prep/failed/test/");
	enqueue(
	    '-v -r -u -1 simple test test',
            qr/punted item reused/,
            1
        );

	# clean up
	system("rm -f /tmp/prep/toingest/test/test.zip /tmp/prep/failed/test/test.zip");
    };
};

runtests unless caller;
