package HTFeed::DBTools;

use strict;
use warnings;
use HTFeed::Config qw(get_config);
use Exporter;
use DBI;
use Sys::Hostname;
use DBD::mysql;
use Log::Log4perl qw(get_logger);
use HTFeed::ServerStatus qw(continue_running_server);
use base qw(Exporter);

=head1 NAME

HTFeed::DBTools

=head1 DESCRIPTION

	Centralized management for DB interactions

=cut

our @EXPORT_OK = qw(get_dbh get_queued lock_volumes update_queue count_locks get_volumes_with_status disconnect);

my $dbh = undef;
my $pid = undef;

sub _init {
    # do not make new db connections if are trying to exit
    continue_running_server or return undef;

    my $dsn = get_config('database','datasource');
    my $user = get_config('database','username');
    my $passwd = get_config('database','password');

    $dbh = DBI->connect($dsn, $user, $passwd,
    {'RaiseError' => 1});

    $pid = $$;

    return($dbh);
}

sub disconnect {
    if($dbh and $pid eq $$) {
        $dbh->disconnect();
    }
    $dbh = undef;
}

sub get_dbh {
    # Reconnect to server if necessary
    unless($dbh and $pid eq $$ and $dbh->ping) {
        _init();
    }

    return($dbh);
}

=item get_queued()

 Return $sth, with rows containing (ns,pkg_type,objid,status)
 for queued volumes locked to host
 unless there are no items, then return false

=cut

sub get_queued{
    my $items = (shift or 1);
    
    my $dbh = get_dbh();

    my $sth = $dbh->prepare(q(SELECT pkg_type, namespace, id, status, failure_count FROM queue WHERE node = ?;));
    $sth->execute(hostname);
    
    return $sth if ($sth->rows);
    return;
}

=item lock_volumes()

 lock_volumes($number_of_items)
 locks available volumes to host, up to $number_of_items
 returns number of volumes locked

=cut

sub lock_volumes{
    my $item_count = shift;
    return 0 unless ($item_count > 0);
    my $release_status = join(',', map {$dbh->quote($_)} @{get_config('release_states')});
    
    # trying to make sure MySQL uses index
    my $sth = get_dbh()->prepare(qq(UPDATE queue SET node = ?, reset_status = status WHERE node IS NULL AND status not in ($release_status) ORDER BY node, status, priority, date_added LIMIT ?;));
    $sth->execute(hostname,$item_count);

    return $sth->rows;
}

=item reset_in_flight_locks()

 Releases locks on in flight volumes
 for this node and resets status to ready

=cut

## TODO: better behavior here, possibly reset to downloaded in some cases, possibly keep lock but reset status
sub reset_in_flight_locks{
    my $release_status = join(',', map {$dbh->quote($_)} @{get_config('release_states')});
    my $sth = get_dbh()->prepare(qq(UPDATE queue SET node = NULL, status = reset_status, reset_status = NULL WHERE node = ? AND status not in ($release_status);));
    return $sth->execute(hostname);
}

=item count_locks()

 Returns the number of volumes locked to this node

=cut

sub count_locks{
    my $sth = get_dbh()->prepare(q(SELECT COUNT(*) FROM queue WHERE node = ?;));
    $sth->execute(hostname);
    return $sth->fetchrow;
}

=item update_queue()

 update_queue($ns, $objid, $new_status, [$release, [$fail]])

 $fail indicates to incriment failure_count
 job will be released if $new_status is a release state

=cut

sub update_queue {
    my ($ns, $objid, $new_status, $release, $fail) = @_;
    
    my $syntax = qq(UPDATE queue SET status = '$new_status');
    $syntax .= q(, failure_count=failure_count+1) if ($fail);
    $syntax .= q(, node = NULL) if ($release);
    $syntax .= qq( WHERE namespace = '$ns' AND id = '$objid';);

    get_dbh()->do($syntax);
}

=item get_volumes_with_status

 get_volumes_with_status($namespace, $pkg_type, $status, $limit)
 returns a reference to a list of objids for all volumes with the given
 namespace, package type.  By default returns all volumes, or will return up
 to $limit volumes if the $limit parameter is given.

=cut

sub get_volumes_with_status {
    my ($pkg_type, $namespace, $status, $limit) = @_;
    my $query = qq(SELECT id FROM queue WHERE namespace = ? and pkg_type = ? and status = ?);
    if($limit) { $query .= " LIMIT $limit"; }
    my $sth = get_dbh()->prepare($query);
    $sth->execute($namespace,$pkg_type,$status);
    my $results = $sth->fetchall_arrayref();
    # extract first (and only) column from results;
    my $toreturn = [ map { $_->[0] } (@$results) ];
    $sth->finish();

    return $toreturn;
}

1;

__END__

=pod

	INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
