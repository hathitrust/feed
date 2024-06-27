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

Display the POD snippets in this file as a help document.

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

if (!caller) {
    GetOptions(
	# these are all booleans
        'clear'    => \my $clear,
        'help'     => \my $help,
        'list'     => \my $list,
        'location' => \my $location,
        'pretty'   => \my $pretty,
        'usage'    => \my $usage,
        # Each operation takes a metric and/or a value:
        # add(metric, value),
        # get_value(metric)
        # inc(metric),
        # match(value),
        # observe(metric, value)
        'operation=s' => \my $operation,
        'metric=s'    => \my $metric,
        'value=s'     => \my $value
    );

    if ($help or $usage) {
        pod2usage(2);
    }

    my $job_metrics = HTFeed::JobMetrics->get_instance();
    my %valid_operations = (
        add       => sub { $job_metrics->add($metric, $value) },
        inc       => sub { $job_metrics->inc($metric) },
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

    # Check the boolean args and act if true.
    if ($clear) {
        print "Clearing data...\n";
        $job_metrics->clear;
        print "Data cleared.\n";
    }
    if ($list) {
        print "# List of metrics:\n";
        print join("\n", @{$job_metrics->list_metrics}) . "\n";
    }
    if ($location) {
        print "# HTFeed::JobMetrics data stored in:\n";
        print $job_metrics->loc . "\n";
    }
    if ($pretty) {
        print $job_metrics->pretty . "\n";
    }

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
        exit(0);
    }
}

1;
