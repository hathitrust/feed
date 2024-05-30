use HTFeed::JobMetrics;
use Plack::Response;

# Metrics exporter for prometheus statistics gathered via ingest.
# Usage: plackup -p 9090 ./bin/metrics_exporter.pl

my $metrics = HTFeed::JobMetrics->get_instance();

my $app = sub {
  my $env = shift;

  my $rendered = $metrics->pretty();
  my $headers = { "Content-Type" => "text/plain" };

  my $response = Plack::Response->new();
  $response->content_type('text/plain');

  if ($rendered) {
    $response->status(200);
    $response->body($rendered);

    return $response->finalize;
  } else {
    $response->status(500);
    $response->body("# metrics rendering failed");

    return $response->finalize;
  }

};
