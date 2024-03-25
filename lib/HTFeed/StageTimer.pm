package HTFeed::StageTimer;

use strict;
use warnings;

use Prometheus::Tiny::Shared;

sub new {
    my $class = shift;
    my $self  = shift || {};

    $self->{file} = "/tmp/foobik";
    $self->{prom} = Prometheus::Tiny::Shared->new(
	filename => $self->{file}
    );

    bless($self, $class);
    $self->_setup_metrics();

    return $self;
}

sub observe { # for histogram metrics
    my $self = shift;
    my $metric = shift;
    my $value = shift;

    if ($self->valid_metric($metric)) {
	$self->{prom}->histogram_observe($metric, $value);
    } else {
	warn "bad metric $metric\n";
    }
}

sub incr { # for simple metrics
    my $self = shift;
    my $metric = shift;
    my $value = shift;

    if ($self->valid_metric($metric)) {
	$self->{prom}->incr($metric);
    } else {
	warn "bad metric $metric\n";
    }
}


sub valid_metric {
    my $self = shift;
    my $metric = shift;

    return defined $self->{metrics}->{$metric};
}

# The leading underscore indicates private
sub _setup_metrics {
    my $self = shift;
    my $prom = $self->{prom};

    $self->{metrics} = {
	
	ms_downloaded => 1,
	kb_downloaded => 1,
	ms_remediated => 1,
	kb_remediated => 1
    };

    foreach my $name (keys %{$self->{metrics}}) {
	my ($type, $stage) = split("_", $name);
	$prom->declare(
	    $name,
	    type => "histogram",
	    help => "$type processed in stage $stage"
	);
    }
}

1;
