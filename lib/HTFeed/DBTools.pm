package HTFeed::DBTools;

use strict;
use warnings;
use HTFeed::Config qw(get_config);
use Exporter;
use DBI;
use DBD::mysql;

use base qw(Exporter);

our @EXPORT_OK = qw(get_dbh);

my $dbh = undef;
my $pid = undef;

sub _init {

    my $self = shift;

    my $dsn = get_config('database','datasource');
    my $user = get_config('database','username');
    my $passwd = get_config('database','password');

    $dbh = DBI->connect($dsn, $user, $passwd,
	{'RaiseError' => 1});

    $pid = $$;

    return($dbh);
}



sub get_dbh {

    # Reconnect to server if necessary
    unless($dbh and $pid eq $$ and $dbh->ping) {
	_init();
    }

    return($dbh);
}

1;
