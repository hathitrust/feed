package HTFeed::JobMetricsCLI;

use strict;
use warnings;

use Getopt::Long;
use HTFeed::JobMetrics;
use Pod::Usage;

=item HTFeed::JobMetricsCLI

=back

A class providing a Command Line Interface to the JobMetrics class.

=item Command line options:

=back

=item --help / --usage

Render the POD in this file as a help document.

=item --loc

Show where the data is stored.

=item --list

Show names of all known metrics.

=item --pretty

Full, somewhat readable, accounting of known metrics and their values.

Call this to export/harvest/scrape data from the running production pod.

=item --clear

Irrevocably delete job metrics (see --loc for where that is)

=item --operation

--operation takes an operation name (match / inc / add/ observe),
a --metric and/or a --value. See below for the different operations.

=item --operation match --value x

Return metrics matching x.

=item --operation get_value --metric x

Returns the value for metric x, 0 in case of any issues.

=item --operation inc --metric x

Increment metric x by 1.

=item --operation add --metric x --value y

Adds arbitrary numeric value y to the metric x.

=item --operation observe --metric x --value y

Add value y to the histogram metric x.

Note that histograms must be set up with buckets ahead of time.

=cut

my $job_metrics = HTFeed::JobMetrics->new();

if (!caller) {
    GetOptions(
	# these are all booleans
        'clear'    => \my $clear,
        'help'     => \my $help,
        'list'     => \my $list,
        'location' => \my $location,
        'pretty'   => \my $pretty,
        'usage'    => \my $usage,
        # Each operation takes a metric and/or a value.
        # add/inc also take an optional labels arg.
        # add(metric, value, labels?),
        # get_value(metric)
        # inc(metric, labels?),
        # match(value),
        # observe(metric, value)
        'operation=s' => \my $operation,
        'metric=s'    => \my $metric,
        'value=s'     => \my $value,
        'labels=s'    => \my $labels_str # optional hash as string = a:b;c:d
    );

    if ($help or $usage) {
        pod2usage(2);
    }

    # Turn the optional labels_str into a hashref
    my $labels = parse_labels($labels_str);

    my %valid_operations = (
        add       => sub { $job_metrics->add($metric, $value, $labels) },
        inc       => sub { $job_metrics->inc($metric, $labels) },
        match     => sub {
            my $matches = $job_metrics->match($value);
            print join("\n", @$matches) . "\n";
        },
        get_value => sub {
            my $value = $job_metrics->get_value($metric);
            if (defined $value) {
                print "$value\n";
            } else {
                print "no value found\n";
            }
        },
        observe => sub { $job_metrics->observe($metric, $value) }
    );

    # Check the boolean args and call associated sub if true.
    $clear    && &clear();
    $list     && &list();
    $location && &location();
    $pretty   && &pretty();

    # Now check the operation arg
    if (defined $operation) {
        if (exists $valid_operations{$operation}) {
            print "running operation $operation ...\n";
            $valid_operations{$operation}();
        } else {
            print "Invalid operation, exiting.\n";
            exit(1);
        }
    } else {
        print "No operation defined, exiting.\n";
    }
    exit(0);
}

# Parse string into hashref,
# "a:b;c:d" -> {a => b, c => d}
sub parse_labels {
    my $str = shift;

    my $href_out = {};
    if ($str) {
        my @key_value_pairs = split(";", $str);
        foreach my $pair (@key_value_pairs) {
            my ($k, $v) = split(":", $pair);
            $href_out->{$k} = $v;
        }
    }

    return $href_out;
}

sub clear {
    print "Clearing data...\n";
    $job_metrics->clear;
    print "Data cleared.\n";
}

sub list {
    print "# List of metrics:\n";
    print join("\n", @{$job_metrics->list_metrics}) . "\n";
}

sub location {
    print "# HTFeed::JobMetrics data stored in:\n";
    print $job_metrics->loc . "\n";
}

sub pretty {
    print $job_metrics->pretty . "\n";
}

1;
