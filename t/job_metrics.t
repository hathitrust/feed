use strict;
use warnings;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::Spec;
use Test::Exception;

use HTFeed::JobMetrics;

describe "HTFeed::JobMetrics" => sub {
    # SETUP start
    my $jm = HTFeed::JobMetrics->get_instance;
    my $item_metric = "ingest_pack_items";
    my $byte_metric = "ingest_pack_bytes";
    my $invalid_metric = "not a valid metric";
    before each => sub {
	$jm->clear() if defined $jm;
    };
    # SETUP end

    # TESTS start
    it "says where the data is stored" => sub {
	# Either the env var is defined, and that's what we use,
	# or we default to a /tmp/ location.
	if (defined $ENV{'HTFEED_JOBMETRICS_DATA_DIR'}) {
	    ok($jm->loc eq $ENV{'HTFEED_JOBMETRICS_DATA_DIR'});
	} else {
	    ok($jm->loc eq "/tmp/htfeed-jobmetrics-data");
	}
    };

    it "lists all known metrics, alphabetically" => sub {
	my $metrics = $jm->list_metrics;
	ok(@$metrics[0]  eq "ingest_collate_bytes");
	ok(@$metrics[-1] eq "ingest_volumevalidator_seconds");
    };
    it "reports no value for an empty matching metric" => sub {
	# get_value is a more useful method, most of the time
	# but match is at least useful for debug/dev purposes
	my $matching = $jm->match($item_metric);
	ok(@$matching == 1);
	ok($$matching[0] =~ /^# TYPE $item_metric counter$/);
    };
    it "reports 0 for any empty or non-existing metrics" => sub {
	my $value_invalid_metric = $jm->get_value($invalid_metric);
	my $value_valid_metric   = $jm->get_value($item_metric);
	ok($value_invalid_metric == 0);
	ok($value_valid_metric   == 0);
    };
    it "reports a value for a non-empty matching metric" => sub {
	$jm->inc($item_metric);
	$jm->inc($item_metric);
	ok($jm->get_value($item_metric) == 2);
    };
    it "allows arbitrary addition" => sub {
	$jm->add($byte_metric, 1.01);
	$jm->add($byte_metric, 3.03);
	ok($jm->get_value($byte_metric) == 4.04);
    };
    it "warns and returns [] if given an invalid metric name" => sub {
	ok($jm->inc($invalid_metric) == 0);
	my $match = $jm->match($invalid_metric);
	ok(ref($match) eq "ARRAY");
	ok(@$match == 0);
    };
    it "allows multiple distinct jms writing (in sequence) to the same metrics file" => sub {
	# Make 5 separate jm objects that all inc $item_metric once,
	# and expect to see "$item_metric 5" in the output for
	# match($item_metric).
	my $expected_count = 5;
	# Get 5 jm instances
	my @jms = (map { HTFeed::JobMetrics->get_instance } (1..5));
	foreach my $sequence_jm (@jms) {
	    $sequence_jm->inc($item_metric);
	}
	ok($jm->get_value($item_metric) == 5);
    };
    it "allows multiple distinct jms writing (in parallel) to the same metrics file" => sub {
	my $fork_count = 5;
	foreach my $_i (1 .. $fork_count) {
	    my $pid = fork; # do the fork
	    die "failed to fork: $!" unless defined $pid;
	    next if $pid;
	    # do the work:
	    $jm->inc($item_metric);
	    # CAVEAT: this exit will trigger after-each hook in SETUP if any,
	    # which can make for some really frustrating debugging.
	    exit;
	}
	my $kid;
	do {
	    $kid = waitpid -1, 0;
	} while ($kid > 0);
	ok($jm->get_value($item_metric) == 5);
    };

    # TESTS todo
    it "could have some histogram tests once we figure out histograms" => sub {};
    # TESTS end
};

runtests unless caller;
