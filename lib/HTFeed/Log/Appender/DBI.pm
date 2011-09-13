package HTFeed::Log::Appender::DBI;

use HTFeed::DBTools qw(get_dbh);
use Carp qw(croak);
use base qw(Log::Log4perl::Appender::DBI);

# override Log::Log4perl::Appender::DBI to use process-wide connection instead of creating another one!

sub _init {
    ; #no-op, no pooling at this level
}
sub create_statement {
    my ($self, $stmt) = @_;

    $stmt || croak "Log4perl: sql not set in ".__PACKAGE__;

    return get_dbh()->prepare($stmt)
    || croak "Log4perl: DBI->prepare failed $DBI::errstr\n$stmt";
}

1;
