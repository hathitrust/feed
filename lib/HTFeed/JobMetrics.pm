package HTFeed::JobMetrics;

use strict;
use warnings;

use Prometheus::Tiny::Shared;

# This module is responsible for measuring job performance in different
# stages. It knows what kinds of things we want to measure, and passes
# each measurement to Prometheus, which writes to a Hash::SharedMem.

### Usage:
#
### display the current metrics:
# $ perl JobMetrics.pm --pretty
#
### just see the list of metrics
# $ perl JobMetrics.pm --list
#
### irrevocably clear current metrics:
# $ perl JobMetrics.pm --clear
#
### add value to histogram metric:
# $ perl JobMetrics.pm --observe <metric> <value>
#
### increment counter metric:
# $ perl JobMetrics.pm --inc <metric>
#
### or:
# use HTFeed::JobMetrics;
# my $jm = HTFeed::JobMetrics->new();
# $jm->inc("fetched_items");       # for counters (/*_items$/)
# $jm->observe("fetched_ms", 220); # for historgrams (/*_(kb|ms)$/)
# print $jm->pretty;
### list available metrics
# $jm->list_metrics

if (!caller) { # If called from commandline:
    my $jm = HTFeed::JobMetrics->new();

    while(my $arg = shift @ARGV) {
	if ($arg =~ /^--pretty$/) {
	    # pass --pretty to see all data pretty-printed
	    print $jm->pretty . "\n";
	} elsif ($arg =~ /^--list$/) {
	    # pass --list to see just the names of known metrics
	    print join("\n", @{$jm->list_metrics});
	} elsif ($arg =~ /^--clear$/) {
	    # pass --clear to irrevocably clear the metrics
	    # (necessary when changing existing metric definitions)
	    $jm->clear();
	    print "JobMetrics cleared!\n";
	} elsif ($arg =~ /^--observe$/) {
	    # pass --observe to call observe(metric, value)
	    # using the next 2 args as metric and value
	    my $metric = shift @ARGV;
	    my $value  = shift @ARGV;
	    $jm->observe($metric, $value);
	} elsif ($arg =~ /^--inc$/) {
	    # pass --inc to call inc(metric)
	    # using the next arg as metric
	    my $metric = shift @ARGV;
	    $jm->inc($metric);
	} else {
	    print "Ignoring invalid arg: $arg\n";
	}
    }
} # no more commandline

sub new {
    my $class = shift;
    my $self  = {};

    # TODO: Need to determine best place to store metrics
    # pod's /tmp? /htprep? some other location?
    $self->{file} = "/tmp/HTFeed::JobMetrics::Data";
    if (defined $ENV{'HTFEED_JOBMETRICS_DATA_DIR'}) {
	$self->{file} = $ENV{'HTFEED_JOBMETRICS_DATA_DIR'};
    }
    $self->{prom} = Prometheus::Tiny::Shared->new(
	filename => $self->{file}
    );

    bless($self, $class);
    $self->_setup_metrics();

    return $self;
}

# for histograms
# e.g. $jm->observe("Unpack_ms", 125);
# or $ perl JobMetrics.pm --observe Unpack_ms 125
sub observe {
    my $self   = shift;
    my $metric = shift;
    my $value  = shift;

    $self->_valid_metric($metric) && $self->{prom}->histogram_observe($metric, $value);
}

# for counters
# e.g. $jm->inc("Unpack_items");
# or $ perl JobMetrics.pm --inc Unpack_items
sub inc {
    my $self   = shift;
    my $metric = shift;

    $self->_valid_metric($metric) && $self->{prom}->inc($metric);
}

# just show names of metrics
sub list_metrics {
    my $self = shift;
    [sort keys %{$self->{metrics}}];
}

# pretty-printable tabular data
sub pretty {
    my $self = shift;
    $self->{prom}->format
}

# irrevocably delete job metrics
sub clear {
    my $self = shift;
    $self->{prom}->clear;
}

# "private" from here on:

# Check that only valid metrics are used,
# or make an intelligent complaint.
# e.g. $jm->_valid_metric("Unpack_ms") # -> 1
# e.g. $jm->_valid_metric("ms pacman") # -> warn & 0
sub _valid_metric { # "private"
    my $self   = shift;
    my $metric = shift;

    return 1 if defined $self->{metrics}->{$metric};

    my ($package, $filename, $line) = caller(1);
    warn "invalid metric name \"$metric\" at $filename:$line\n";
    return 0;
}

sub _setup_metrics {
    my $self = shift;
    my $prom = $self->{prom};

    # Each element x in this array gets turned into 3 prom declarations:
    # x_ms, x_kb and x_count
    my @measurable_stages = (
	'Collate',
	'Download',
	'Download_dropbox',
	'Download_google',
	'Download_ia',
	'Handle',
	'ImageRemediate',
	'METS',
	'Pack',
	'SourceMETS',
	'Unpack',
	'VerifyManifest',
	'VolumeValidator'
    );

    my @scales = qw(items kb ms);
    # essentially, generate: @measurable_stages x @scales
    # so that we get Pack_items, Pack_kb, Pack_ms ... etc

    # In case we want different bucket setup for different scales
    my %scale_buckets = (
	kb => _kilobyte_buckets(),
	ms => _millisecond_buckets()
    );

    $self->{metrics} = {};
    foreach my $stage (@measurable_stages) {
	foreach my $scale (@scales) {
	    # e.g. $self->{metrics}->{Pack_items} = 1
	    my $metric_name = $stage ."_". $scale;
	    $self->{metrics}->{$metric_name} = 1;
	    if ($scale eq "items") {
		$prom->declare($metric_name, type => "counter");
	    } else { # here, scale is either kb or ms
		my $buckets = $scale_buckets{$scale};
		$prom->declare(
		    $metric_name,
		    type    => "histogram",
		    buckets => $buckets
		);
	    }
	}
    }
}

# NB that if you change these bucket definitions, you need to clear
# existing data, or prometheus will complain:
# "redeclaration of <metric_name> with mismatched meta"
sub _millisecond_buckets {
    [
	10, # 10 ms
	50,
	100,
	500,
	1_000,
	5_000, # 5 seconds
	10_000,
	50_000,
	100_000,
	500_000,
	1000_000,
	5000_000 # 5000 seconds ~ 1h 23 min
    ];
}

sub _kilobyte_buckets {
    [
	100, # 100 kb
	500,
	1_000,
	5_000,
	10_000,
	50_000, # ~50 MB
	100_000,
	500_000,
	1000_000,
	5000_000 # ~5 GB
    ];
}

1;
