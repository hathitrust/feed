package HTFeed::JobMetrics;

use strict;
use warnings;

use Prometheus::Tiny::Shared;

# This module is responsible for measuring job performance in different
# stages. It knows what kinds of things we want to measure, and passes
# each measurement to a file by prometheus.

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

    # pass --pretty to see all data pretty-printed
    if (grep { /^--pretty$/ } @ARGV) {
	print $jm->pretty . "\n";
    }

    # pass --list to see just the names of known metrics
    if (grep { /^--list$/ } @ARGV) {
	print join("\n", @{$jm->list_metrics});
    }

    # pass --clear to irrevocably clear the metrics
    # (necessary when changing existing metric definitions)
    if (grep { /^--clear$/ } @ARGV) {
	$jm->clear();
	print "JobMetrics cleared!\n";
    }
}

sub new {
    my $class = shift;
    my $self  = {};

    # TODO: Need to determine best place to store metrics
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

sub observe { # for histograms
    my $self   = shift;
    my $metric = shift;
    my $value  = shift;

    $self->valid_metric($metric) && $self->{prom}->histogram_observe($metric, $value);
}

sub inc { # for counters
    my $self   = shift;
    my $metric = shift;

    $self->valid_metric($metric) && $self->{prom}->inc($metric);
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

sub clear {
    my $self = shift;
    $self->{prom}->clear;
}

# Check that only valid metrics are used,
# or make an intelligent complaint.
sub valid_metric {
    my $self   = shift;
    my $metric = shift;

    return 1 if defined $self->{metrics}->{$metric};

    my ($package, $filename, $line) = caller(1);
    warn "invalid metric name \"$metric\" at $filename:$line\n";
    return 0;
}

# The leading underscore indicates private
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
    # so that we get packed_items, packed_kb, packed_ms ... etc
    $self->{metrics} = {};
    foreach my $stage (@measurable_stages) {
	foreach my $scale (@scales) {
	    # e.g. $self->{metrics}->{Unpack_items} = 1
	    my $metric_name = $stage ."_". $scale;
	    $self->{metrics}->{$metric_name} = 1;
	    if ($scale eq "items") {
		$prom->declare($metric_name, type => "counter");
	    } else {
		$prom->declare($metric_name, type => "histogram");
	    }
	}
    }
}

1;
