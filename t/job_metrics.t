use strict;
use warnings;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::Spec;
use Test::Exception;
use Time::HiRes qw(usleep);

use HTFeed::JobMetrics;

describe "HTFeed::JobMetrics" => sub {
    # SETUP start
    my $jm             = HTFeed::JobMetrics->new;
    my $item_metric    = "ingest_pack_items_total";
    my $byte_metric    = "ingest_pack_bytes_w_total";
    my $invalid_metric = "not a valid metric";
    my $label          = "test_label";
    my $label_value    = "ok";

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
        ok(@$metrics[0]  eq "ingest_collate_bytes_r_total");
        ok(@$metrics[-1] eq "ingest_volumevalidator_seconds_total");
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
        my @jms = (map { HTFeed::JobMetrics->new } (1..5));
        foreach my $sequence_jm (@jms) {
            $sequence_jm->inc($item_metric);
        }
        ok($jm->get_value($item_metric) == 5);
    };
    it "allows multiple distinct jms writing (in parallel) to the same metrics file" => sub {
        my $fork_count = 5;
        foreach my $_i (1 .. $fork_count) {
            my $pid = fork;     # do the fork
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
    it "reports time w/ second as base unit, at high resolution" => sub {
        # To test this, we take a time measurement ($t1),
        # nap for a short predefined amount of time ($sleep_time),
        # and take another time measurement ($t2).
        # Then we verify that $t2 - $t1 is almost exactly
        # the same amount of time as $sleep_time.

        my $t1                     = $jm->time;
        my $sleep_time             = 0.1;
        my $sleep_time_in_microsec = $sleep_time * 1000000;
        my $resolution_tolerance   = 0.01;

        usleep $sleep_time_in_microsec;
        my $t2      = $jm->time;
        my $delta_t = $t2 - $t1;

        # Now prove that t1 and t2 are (very close to) $sleep_time sec apart.
        ok(    ($delta_t - $sleep_time) < $resolution_tolerance);
        # e.g. (0.103... - 0.1        ) < 0.01
    };
    it "reports dir size, recursively, with bytes as base unit" => sub {
        # To check that it counts file sizes recursively,
        # we have this fixture dir:
        #
        # feed/t/fixtures/dir_size$ tree
        # .
        # ├── README1 (108B)
        # ├── README2 (36B)
        # └── subdir
        #     └── README3 (66B)
        #
        # Please don't change anything in these fixture dirs,
        # without also updating the dir sizes in this test.

        my $dir                  = "/usr/local/feed/t/fixtures/dir_size";
        my $expected_dir_size    = 210; # (108 + 36) + 66
        my $subdir               = "$dir/subdir";
        my $expected_subdir_size = 66;

        ok($jm->dir_size($dir)    == $expected_dir_size);
        ok($jm->dir_size($subdir) == $expected_subdir_size);
    };
    it "allows labels passed to inc" => sub {
        $jm->inc($item_metric, {$label => $label_value});
        my $match = $jm->match($item_metric);
        # we can set the value when passing label:
        ok($jm->get_value($item_metric) == 1);
        # we didn't create superfluous entries when passing a label:
        ok(@$match == 2);
        # we can see the label in match output (which is based on pretty output)
        # so we know prometheus stored the label
        ok($$match[1] eq "ingest_pack_items_total{test_label=\"ok\"} 1");
    };
    it "allows labels passed to add" => sub {
        my $bytes = 123;
        $jm->add($byte_metric, $bytes, {$label => $label_value});
        my $match = $jm->match($byte_metric);
        ok($jm->get_value($byte_metric) == $bytes);
        ok(@$match == 2);
        ok($$match[1] eq "ingest_pack_bytes_w_total{test_label=\"ok\"} $bytes");
    };
    it "wants labels as hashref, otherwise warns & ignores them" => sub {
        $jm->inc($item_metric, "this will work BUT labels will be ignored");
        my $match = $jm->match($item_metric);
        # there is no label in the match return
        ok($$match[1] eq "ingest_pack_items_total 1");
    };
    it "wants simple label values, nested data will be stripped" => sub{
        $jm->inc(
            $item_metric,
            {$label => ['nested dont work']}
        );

        # We see no such label in the match return...
        my $match_on_label = $jm->match("nested dont work");
        ok(@$match_on_label == 0);

        # ... but the metric got incremented without the label.
        my $metric_value = $jm->get_value($item_metric);
        ok($metric_value == 1);
    };

    # TESTS todo
    it "could have some histogram tests once we figure out histograms" => sub {};
    # TESTS end
};

runtests unless caller;
