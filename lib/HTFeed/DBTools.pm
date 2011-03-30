package HTFeed::DBTools;

use strict;
use warnings;
use HTFeed::Config qw(get_config);
use Exporter;
use DBI;
use Sys::Hostname;
use DBD::mysql;

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

# enqueue(\@volumes)
# 
# add volumes to queue
sub enqueue_volumes{
    my $volumes = shift;
    my $ignore = shift;
    
    $dbh = get_dbh();
    my $sth;
    if($ignore){
        $sth = $dbh->prepare(q(INSERT IGNORE INTO queue (pkg_type, namespace, id) VALUES (?,?,?);));
    }else {
        $sth = $dbh->prepare(q(INSERT INTO queue (pkg_type, namespace, id) VALUES (?,?,?);));
    }
    
    my @results;
    foreach my $volume (@{$volumes}){
        eval{
            push @results, $sth->execute($volume->get_packagetype(), $volume->get_namespace(), $volume->get_objid());
        } or print $@ and return \@results;
    }
    return \@results;
}

# reset(\@volumes, $force)
# 
# reset punted volumes, reset all volumes if $force
sub reset_volumes{
    my $volumes = shift;
    my $force = shift;
    
    $dbh = get_dbh();
    my $sth;
    if($force){
        $sth = $dbh->prepare(q(UPDATE queue SET node = NULL, status = 'ready', failure_count = 0 WHERE namespace = ? and id = ?;));
    }
    else{
        $sth = $dbh->prepare(q(UPDATE queue SET node = NULL, status = 'ready', failure_count = 0 WHERE status = 'punted' and namespace = ? and id = ?;));
    }
    
    my @results;
    foreach my $volume (@{$volumes}){
        push @results, $sth->execute($volume->get_namespace(), $volume->get_objid());
    }
    return \@results;
}

# lock_volumes($number_of_items)
# locks available volumes to host, up to $number_of_items
# returns number of volumes locked
sub lock_volumes{
    my $item_count = shift;
#    warn("Locking $item_count volumes to " . hostname . "\n"); 
    return 0 unless ($item_count > 0);
    
    ## TODO: order by priority
    my $sth = get_dbh()->prepare(q(UPDATE queue SET node = ? WHERE node IS NULL AND status = 'ready' LIMIT ?;));
    $sth->execute(hostname,$item_count);

#    $sth = get_dbh()->prepare(q(SELECT pkg_type, namespace, id FROM queue WHERE node = ?));
#    $sth->execute(hostname);
#    my $count = 0;
#    while(my $row = $sth->fetchrow_arrayref()) {
#        warn "Locked to " . hostname . ": " . join(" ",@$row), "\n";
#        $count++;
#    }
#    warn "Total locked to " . hostname . ": $count \n";

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

# update_queue($ns, $objid, $new_status, [$fail])
# $fail indicates to incriment failure_count
# job will be released if $new_status is a release state
sub update_queue {
    my ($ns, $objid, $new_status, $fail) = @_;
    
    my $syntax = qq(UPDATE queue SET status = '$new_status');
    $syntax .= q(, failure_count=failure_count+1) if ($fail);
    $syntax .= q(, node = NULL) if (exists $release_states{$new_status});
    $syntax .= qq( WHERE namespace = '$ns' AND id = '$objid';);
    
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
