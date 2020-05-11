package HTFeed::Test::Logger;

use HTFeed::Log {root_logger => 'TRACE, string, screen'};
use Log::Log4perl::Appender::String;
use Log::Log4perl qw(get_logger);

sub new {
  my $class = shift;
  my $self = { appender => Log::Log4perl->appender_by_name("string") };
  return bless($self,$class);
}

sub matches {
  my $self = shift;
  my $pattern = shift;
  return $self->{appender}->string() =~ $pattern;
}

sub reset {
  my $self = shift;
  $self->{appender}->string("");
}

1;
