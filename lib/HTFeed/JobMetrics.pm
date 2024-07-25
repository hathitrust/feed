package HTFeed::JobMetrics;

use strict;
use warnings;
use File::Find;
use Log::Log4perl qw(get_logger);
use Prometheus::Tiny::Shared;
use Time::HiRes;

# TODO: mw 2024 // simplify predefined metrics.
# Since it is already starting to grow out of hand...
# I still want metric base names to be predefined, and a predefined set
# of units. E.g. @metrics = qw(ingest_download ingest_pack)
# and @units = qw(seconds bytes_r bytes_w items images)

=item HTFeed::JobMetrics

=back

... a class that can be used to gather metrics on
the various stages of an ingest job, such as number of items downloaded,
number of bytes downloaded and amount of time spent downloading
(as well as the other job stages, not just download).

This class implements the singleton pattern. The singleton instance is
stored in the aptly named $singleton variable.

CLI provided by and documented in JobMetricsCLI.pm.

=item See e.g.:

  https://www.perl.com/article/52/2013/12/11/Implementing-the-singleton-pattern-in-Perl/

=back

=cut

my $singleton = undef;

# This class implements the singleton pattern (but constructor is still new()).
sub new {
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

# Show where the data is stored.
sub loc {
    my $self = shift;

    $self->{file};
}

# Show names of all known metrics.
sub list_metrics {
    my $self = shift;

    [sort keys %{$self->{metrics}}];
}


# Full, somewhat readable, accounting of known metrics and their values.
sub pretty {
    my $self = shift;

    $self->{prom}->format;
}

# Irrevocably delete job metrics
sub clear {
    my $self = shift;

    $self->{prom}->clear;
}

# Return matching lines from pretty output
sub match {
    my $self   = shift;
    my $value  = shift;
    die "match requires a value" if !defined $value;

    my @pretties = split("\n", $self->pretty);

    [grep { /$value/ } @pretties];
}

# Return value for a given metric
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

# Increment the given metric (w/ optional labels href)
sub inc {
    my $self   = shift;
    my $metric = shift;
    my $labels = shift || {};

    # sets to {} if invalid
    $labels = $self->_valid_labels($labels);

    if ($self->_valid_metric($metric)) {
        $self->{prom}->inc($metric, $labels);
    }
}

# Add to the value of the given counter metric (w/ optional labels href)
sub add {
    my $self   = shift;
    my $metric = shift;
    my $value  = shift;
    my $labels = shift || {};

    # sets to {} if invalid
    $labels = $self->_valid_labels($labels);

    # Make sure $value is defined and numeric
    unless (defined $value) {
        get_logger()->warn("Undefined value given for $metric");
        return;
    }
    unless ($value + 0 >= 0) {
        get_logger()->warn("Non-numeric value \"$value\" given for $metric");
        return;
    }

    $self->_valid_metric($metric) && $self->{prom}->add($metric, $value, $labels);
}

# Add to the buckets of the given bucket metric
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

# We want the size of a directory (recursively) for certain metrics.
# Example:
#   HTFeed::JobMetrics->dir_size($some_dir) -> 12345;
sub dir_size {
    shift if (ref $_[0]);       # Discard $self if passed in.
    my $dir = shift;

    my $size = 0;
    find(
        sub {
            $size += -s if -f;
        },
        $dir
    );

    return $size;
}

# So that classes that want to measure time don't need to include
# Time::HiRes themselves.
sub time {
    Time::HiRes::time();
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

# Labels must be sent as a hashref with simple key-value pairs.
# Not going to impose any stricter validation at this point.
# Keys and values will be lowercased.
# Labels do NOT need to be predefined, unlike metrics.
sub _valid_labels {
    my $self    = shift;
    my $labels  = shift;

    my $reftype = ref $labels;
    if ($reftype ne "HASH") {
        my (undef, $filename, $line) = caller(1);
        get_logger()->warn("invalid labels (must be HASH ref) at $filename:$line");

        return {};
    }

    # No nested data here, delete on sight.
    foreach my $k (keys %$labels) {
        my $v = $labels->{$k};
        if (ref $v) {
            get_logger()->warn(
                "No nested values allowed in labels. Deleting label $k => $v\n"
            );
            delete $labels->{$k};
            next;
        }
    }

    # lowercase the whole hashref, now that keys & vals are known to be fine
    $labels = { map lc, %$labels };

    return $labels;
}

sub _setup_metrics {
    my $self = shift;
    my $prom = $self->{prom};

    # Prefix all metric names with:
    my $pfx = "ingest";

    # Each element in @measurable_stages gets combined with
    # each element in @units, to produce e.g. pack_items etc.
    # Names are based on the downcased class name of the stage,
    # or method in which the measured event happens.
    my @measurable_stages = (
        'collate',
        'download',
        'download_dropbox',
        'download_google',
        'download_ia',
        'handle',
        'imageremediate',
        'encrypt',
        'mets',
        'move',
        'pack',
        'postvalidate',
        'prevalidate',
        'record_audit',
        'record_backup',
        'sourcemets',
        'stage',
        'unpack',
        'validate_zip_completeness',
        'verify_crypt',
        'verifymanifest',
        'volumevalidator',
    );
    my @units = (
        'bytes_r',
        'bytes_w',
        'items',
        'seconds',
    );

    # In case we want different bucket setup for different units.
    # Leaving bytes and seconds commented out for now, meaning
    # we will not have any histograms.
    my %unit_buckets = (
        # bytes   => _byte_buckets(),
        # seconds => _second_buckets()
    );

    $self->{metrics} = {};
    foreach my $stage (@measurable_stages) {
        foreach my $unit (@units) {
            my $metric_name = join("_", ($pfx, $stage, $unit));
            if (defined $unit_buckets{$unit}) {
                # If $unit defined in %unit_buckets, make $metric_name a histogram
                # and use the bucket scheme appropriate for the unit
                # here, unit is either bytes or seconds
                my $buckets = $unit_buckets{$unit};
                $prom->declare(
                    $metric_name,
                    type    => "histogram",
                    buckets => $buckets
                );
            } else {
                # If nothing in particular was said abut the metric or the unit,
                # turn it into a counter.
                # It is good prometheus practice to end counter names with "_total".
                $metric_name .= "_total";
                $prom->declare($metric_name, type => "counter");
            }
            $self->{metrics}->{$metric_name} = 1;
        }
    }

    # Declare any other metrics here that don't fit
    # the @measurable_stages x @units recipe:
    $self->{metrics}->{$pfx . "_imageremediate_images_total"} = 1;
    $prom->declare($pfx . "_imageremediate_images_total", type => "counter");
}

# NB that if you change these bucket definitions, you need to clear
# existing data, or prometheus will complain:
# "redeclaration of <metric_name> with mismatched meta"
# Manipulate _setup_metrics to change which metrics are histograms,
# and which buckets they should use.
sub _second_buckets {
    [
        0.001,                  # 1 millisec
        0.01,
        0.1,
        1,                      # 1 sec
        10,
        60,                     # 1 minute
        300,                    # 5 minutes
        6000,                   # 10 minutes
        3_600,                  # 1 hour
        7_200,                  # 2 hours
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
