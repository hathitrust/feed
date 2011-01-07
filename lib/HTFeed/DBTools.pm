package HTFeed::DBTools;

use strict;
use warnings;
use HTFeed::Config qw(get_config);
use Exporter;
use DBI;
use Sys::Hostname;
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

# get_queued()
# return $sth, with rows containing (ns,pkg_type,objid,status)
# for queued volumes locked to host
# unless there are no items, then return false
sub get_queued{
    my $items = (shift or 1);
    
    my $dbh = get_dbh();
    ## TODO: order by priority
    my $sth = $dbh->prepare(q(SELECT ns, pkg_type, objid, status, failure_count FROM queue WHERE node = ? AND status != 'punted' AND status !=  'collated' and status != 'held'));
    $sth->execute(hostname);
    
    return $sth if ($sth->rows);
    return;
}

# enqueue(\@volumes)
# 
# add volumes to queue
sub enqueue{
    my $volumes = shift;
    
    $dbh = get_dbh();
    my $sth = $dbh->prepare(q(INSERT INTO `queue` (ns, pkg_type, objid) VALUES (?,?,?)));
    
    foreach my $volume (@{$volumes}){
        $sth->execute($volume->get_packagetype(), $volume->get_namespace(), $volume->get_objid());
    }
}

# lock_volumes($number_of_items)
# locks available volumes to host, up to $number_of_items
# returns number of volumes locked
sub lock_volumes{
    my $item_count = shift;
    return 0 unless ($item_count > 0);
    
    ## TODO: order by priority
    my $sth = get_dbh()->prepare(q(UPDATE queue SET node = ? WHERE node IS NULL AND status = 'ready' LIMIT ?;));
    $sth->execute(hostname,$item_count);
    return $sth->rows;
}

# reset_in_flight_locks()
# releases locks on in flight volumes for this node and resets status to ready
sub reset_in_flight_locks{
    my $sth = get_dbh()->prepare(q(UPDATE queue SET `node` = NULL, `status` = 'ready' WHERE node = ? AND status != 'punted' AND status != 'collated';));
    return $sth->execute(hostname);
}

# release_completed_locks()
# releases locks on in completed volumes for this node
sub release_completed_locks{
    my $sth = get_dbh()->prepare(q(UPDATE queue SET `node` = NULL WHERE node = ? AND status = 'collated';));
    return $sth->execute(hostname);
}

# release_failed_locks()
# releases locks on in failed volumes for this node
sub release_failed_locks{
    my $sth = get_dbh()->prepare(q(UPDATE queue SET `node` = NULL WHERE node = ? AND status = 'punted'));
    return $sth->execute(hostname);
}

# count_locks()
# returns the number of volumes locked to this node
sub count_locks{
    my $sth = get_dbh()->prepare(q(SELECT COUNT(*) FROM queue WHERE node = ? AND status != 'punted' AND status != 'collated';));
    $sth->execute(hostname);
    return $sth->fetchrow;
}

1;
