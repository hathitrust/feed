use strict;
use warnings;

use HTFeed::JobMetrics;
use Plack::Response;

# Metrics exporter for prometheus statistics gathered via ingest.
# Usage: plackup -p 9090 ./bin/metrics_exporter.pl

my $metrics = HTFeed::JobMetrics->new();

my $app = sub {
    my $env = shift;

    my $rendered = $metrics->pretty();
    my $response = Plack::Response->new();
    $response->content_type('text/plain');

    if ($rendered) {
        $response->status(200);
        $response->body($rendered);
    } else {
        $response->status(500);
        $response->body("# metrics rendering failed");
    }

    return $response->finalize;
};
