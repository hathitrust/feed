package HTFeed::DBTools;

use strict;
use warnings;
use HTFeed::Config qw(get_config);
use Exporter;
use DBI;
use Sys::Hostname;
use DBD::mysql;
use Log::Log4perl qw(get_logger);

use base qw(Exporter);

our @EXPORT_OK = qw(get_dbh get_queued lock_volumes update_queue count_locks get_volumes_with_status);

my %release_states = map {$_ => 1} @{get_config('daemon'=>'release_states')};

my $dbh = undef;
my $pid = undef;

sub _init {
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

    my $sth = $dbh->prepare(q(SELECT pkg_type, namespace, id, status, failure_count FROM queue WHERE node = ?;));
    $sth->execute(hostname);
    
    return $sth if ($sth->rows);
    return;
}

# lock_volumes($number_of_items)
# locks available volumes to host, up to $number_of_items
# returns number of volumes locked
sub lock_volumes{
    my $item_count = shift;
    return 0 unless ($item_count > 0);
    
    # trying to make sure MySQL uses index
    my $sth = get_dbh()->prepare(q(UPDATE queue SET node = ? WHERE node IS NULL AND status = 'ready' ORDER BY node, status, priority, date_added LIMIT ?;));
    $sth->execute(hostname,$item_count);

    return $sth->rows;
}

## TODO: better behavior here, possibly reset to downloaded in some cases, possibly keep lock but reset status
# reset_in_flight_locks()
# releases locks on in flight volumes for this node and resets status to ready
sub reset_in_flight_locks{
    my $sth = get_dbh()->prepare(q(UPDATE queue SET node = NULL, status = 'ready' WHERE node = ? AND status != 'punted' AND status != 'collated';));
    return $sth->execute(hostname);
}

# count_locks()
# returns the number of volumes locked to this node
sub count_locks{
    my $sth = get_dbh()->prepare(q(SELECT COUNT(*) FROM queue WHERE node = ?;));
    $sth->execute(hostname);
    return $sth->fetchrow;
}

# ingest_log_failure ($volume,$stage,$status)
sub ingest_log_failure {
    my ($volume,$stage,$new_status) = @_;
    my $ns = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my $stagename = "Unknown error";
    if(defined $stage and ref($stage)) {
        $stagename = "Error in " . ref($stage)
    }
    my $fatal = ($new_status eq 'punted');
    my $sth = get_dbh()->prepare("INSERT INTO ingest_log (namespace,id,status,fatal) VALUES (?,?,?,?)");
    $sth->execute($ns,$objid,$stagename,$fatal);
}

sub ingest_log_success {
    my ($volume,$repeat) = @_;
    my $ns = $volume->get_namespace();
    my $objid = $volume->get_objid();

    my $sth = get_dbh()->prepare("INSERT INTO ingest_log (namespace,id,status,isrepeat) VALUES (?,?,'ingested',?)");
    $sth->execute($ns,$objid,$repeat);
}

# update_queue($ns, $objid, $new_status, [$release, [$fail]])
# $fail indicates to incriment failure_count
# job will be released if $new_status is a release state
sub update_queue {
    my ($ns, $objid, $new_status, $release, $fail) = @_;
    
    my $syntax = qq(UPDATE queue SET status = '$new_status');
    $syntax .= q(, failure_count=failure_count+1) if ($fail);
    $syntax .= q(, node = NULL) if (exists $release_states{$new_status});
    $syntax .= qq( WHERE namespace = '$ns' AND id = '$objid';);
    #print '$ns, $objid, $new_status, $fail';
    #print "\n$ns, $objid, $new_status, $fail\n";
    #print "$syntax\n\n";
    get_dbh()->do($syntax);
}

# get_volumes_with_status($namespace, $pkg_type, $status, $limit)
# Returns a reference to a list of objids for all volumes with the given
# namespace, package type.  By default returns all volumes, or will return up
# to $limit volumes if the $limit parameter is given.
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
