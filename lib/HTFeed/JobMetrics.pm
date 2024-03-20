package HTFeed::JobMetrics;

use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl qw(get_logger);
use Pod::Usage;
use Prometheus::Tiny::Shared;

=item HTFeed::JobMetrics

=back

... a class that can be used to gather metrics on
the various stages of an ingest job, such as number of items downloaded,
number of bytes downloaded and amount of time spent downloading
(as well as the other job stages, not just download).

This class implements the singleton pattern, and as such has a
get_instance() method instead of a "normal" new() function.

The singleton instance is stored in the aptly named
$singleton variable.

=item See e.g.:

  https://www.perl.com/article/52/2013/12/11/Implementing-the-singleton-pattern-in-Perl/

=back

=item Command line options:

=back

=item --help / --usage

Display the POD snippets in this file as a help document.

=cut

# If called from terminal:
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
# end commandline stuff

my $singleton = undef;

sub get_instance {
    # Re-use singleton if defined.
    if (!defined $singleton) {
	my $class = shift;
	my $self  = {};
	# The default location for storing metrics data is under /tmp/.
	# You can ovverride that w/ $ENV{'HTFEED_JOBMETRICS_DATA_DIR'}.
	$self->{file} = "/tmp/htfeed-jobmetrics-data";
	if (defined $ENV{'HTFEED_JOBMETRICS_DATA_DIR'}) {
	    $self->{file} = $ENV{'HTFEED_JOBMETRICS_DATA_DIR'};
	}
	$self->{prom} = Prometheus::Tiny::Shared->new(
	    filename => $self->{file}
	);
	$singleton = bless($self, $class);
	$singleton->_setup_metrics();
    }
    return $singleton;
}

=item --loc

Show where the data is stored.

=cut

sub loc {
    my $self = shift;
    $self->{file};
}

=item --list

Show names of all known metrics.

=cut

sub list_metrics {
    my $self = shift;
    [sort keys %{$self->{metrics}}];
}

=item --pretty

Full, somewhat readable, accounting of known metrics and their values.

Call this to export/harvest/scrape data from the running production pod.

=cut

sub pretty {
    my $self = shift;
    $self->{prom}->format;
}

=item --clear

Irrevocably delete job metrics (see --loc for where that is)

=cut

sub clear {
    my $self = shift;
    $self->{prom}->clear;
}

=item --operation

--operation takes an operation name (match / inc / add/ observe),
a --metric and/or a --value. See below for the different operations.

=item --operation match --value x

Return metrics matching x.

=cut

sub match {
    my $self   = shift;
    my $value  = shift;
    die "match requires a value" if !defined $value;

    my @pretties = split("\n", $self->pretty);
    [grep { /$value/ } @pretties];
}

=item --operation get_value --metric x

Returns the value for metric x, 0 in case of any issues.

=cut

sub get_value {
    my $self   = shift;
    my $metric = shift;

    if (!$self->_valid_metric($metric)) {
	return 0;
    }

    my $match = $self->match("^$metric");
    if (scalar @$match == 1) {
	if ($$match[0] =~ /(\d+(?:\.\d+)?)$/) {
	    my $matched_numerical_value = $1;
	    return $matched_numerical_value;
	}
    }
    get_logger()->warn("JobMetric found no value for $metric");
    return 0;
}

=item --operation inc --metric x

Increment metric x by 1.

=cut

sub inc {
    my $self   = shift;
    my $metric = shift;
    if ($self->_valid_metric($metric)) {
	$self->{prom}->inc($metric);
    }
}

=item --operation add --metric x --value y

Adds arbitrary numeric value y to the metric x.

=cut

sub add {
    my $self   = shift;
    my $metric = shift;
    my $value  = shift;

    # Make sure $value is defined and numeric
    unless (defined $value) {
	get_logger()->warn("Undefined value given for $metric");
	return;
    }
    unless ($value + 0) {
	get_logger()->warn("Non-numeric value \"$value\" given for $metric");
	return;
    }

    $self->_valid_metric($metric) && $self->{prom}->add($metric, $value);
}

=item --operation observe --metric x --value y

Add value y to the histogram metric x.

Note that histograms must be set up with buckets ahead of time.

=cut

sub observe {
    my $self   = shift;
    my $metric = shift;
    my $value  = shift;

    # Make sure $value is numeric
    unless ($value + 0) {
	get_logger()->warn("Non-numeric value \"$value\" given for $metric");
	return;
    }

    $self->_valid_metric($metric) && $self->{prom}->histogram_observe($metric, $value);
}

# "private" from here on, indicated with _leading_underscores
# in method names

# Check that only valid metrics are used,
# or make an intelligent complaint.
# e.g. $job_metrics->_valid_metric("Unpack_seconds") # -> 1
# e.g. $job_metrics->_valid_metric("invalid metric name") # -> warn & 0
sub _valid_metric {
    my $self   = shift;
    my $metric = shift;

    return 1 if defined $self->{metrics}->{$metric};

    # caller 1: we don't want the line number from the call inside this package.
    # remember, this is a "private" method.
    my (undef, $filename, $line) = caller(1);
    get_logger()->warn("invalid metric name \"$metric\" at $filename:$line");
    # switch from warn to die to ensure no invalid metric names slip thru:
    # die ("invalid metric name \"$metric\" at $filename:$line");
    return 0;
}

sub _setup_metrics {
    my $self = shift;
    my $prom = $self->{prom};

    # Prefix all metric names with:
    my $pfx = "ingest";

    # Each element x in this array gets turned into 3 prom declarations:
    # x_seconds, x_bytes and x_items
    # Names are based on the downcased class name of the stage.
    my @measurable_stages = (
	'collate',
	'download',
	'download_dropbox',
	'download_google',
	'download_ia',
	'handle',
	'imageremediate',
	'mets',
	'pack',
	'sourcemets',
	'unpack',
	'verifymanifest',
	'volumevalidator'
    );

    my @scales = qw(items bytes seconds);
    # essentially, generate: @measurable_stages x @scales
    # so that we get Pack_items, Pack_bytes, Pack_seconds ... etc

    # In case we want different bucket setup for different scales.
    # Leaving bytes and seconds commented out for now, meaning
    # we will not have any histograms.
    my %scale_buckets = (
	# bytes   => _byte_buckets(),
	# seconds => _second_buckets()
    );

    $self->{metrics} = {};
    foreach my $stage (@measurable_stages) {
	foreach my $scale (@scales) {
	    my $metric_name = join("_", ($pfx, $stage, $scale));
	    $self->{metrics}->{$metric_name} = 1;
	    if (defined $scale_buckets{$scale}) {
		# If $scale defined in %scale_buckets, make $metric_name a histogram
		# and use the bucket scheme appropriate for the scale
		# here, scale is either bytes or seconds
		my $buckets = $scale_buckets{$scale};
		$prom->declare(
		    $metric_name,
		    type    => "histogram",
		    buckets => $buckets
		);
	    } else {
		# If nothing in particular was said abut the metric or the scale,
		# turn it into a counter.
		$prom->declare($metric_name, type => "counter");
	    }
	}
    }

    # Put in any one-offs that don't fit the above algorithm here:
    $self->{metrics}->{$pfx . "_imageremediate_images"} = 1;
    $prom->declare($pfx . "_imageremediate_images", type => "counter");
}

# NB that if you change these bucket definitions, you need to clear
# existing data, or prometheus will complain:
# "redeclaration of <metric_name> with mismatched meta"
# Manipulate _setup_metrics to change which metrics are histograms,
# and which buckets they should use.
sub _second_buckets {
    [
	0.001, # 1 millisec
	0.01,
	0.1,
	1,     # 1 sec
	10,
	60,    # 1 minute
	300,   # 5 minutes
	6000,  # 10 minutes
	3_600, # 1 hour
	7_200, # 2 hours
    ];
}

sub _byte_buckets {
    [
	1_000,
	10_000,
	100_000,
	1_000_000,
	10_000_000,
	100_000_000,
	1_000_000_000
    ];
}

1;
