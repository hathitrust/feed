package HTFeed::DBTools::Queue;

=description
    All queries for queue that are not in running ingest steps
    
=cut

use warnings;
use strict;
use Carp;
use base qw(HTFeed::DBTools);
use HTFeed::DBTools::Priority qw(reprioritize initial_priority);

use Log::Log4perl qw(get_logger);

our @EXPORT = qw(enqueue_volumes reset_volumes);

# enqueue(\@volumes)
# 
# add volumes to queue
sub enqueue_volumes{
    my $volumes = shift;
    my $ignore = shift;
    
    my $dbh = HTFeed::DBTools::get_dbh();
    my $sth;
    my $blacklist_sth = $dbh->prepare("SELECT namespace, id FROM mdp_tracking.blacklist WHERE namespace = ? and id = ?");
    if($ignore){
        $sth = $dbh->prepare(q(INSERT IGNORE INTO queue (pkg_type, namespace, id, priority) VALUES (?,?,?,?);));
    }else {
        $sth = $dbh->prepare(q(INSERT INTO queue (pkg_type, namespace, id, priority) VALUES (?,?,?,?);));
    }
    
    my @results;
    foreach my $volume (@{$volumes}){
        eval{
            # First make sure volume is not on the blacklist.
            my $namespace = $volume->get_namespace();
            my $objid = $volume->get_objid();

            $blacklist_sth->execute($namespace,$objid);
            if($blacklist_sth->fetchrow_array()) {
                get_logger()->warn("Blacklisted",namespace=>$namespace,objid=>$objid);
                push(@results,0);
                return;
            }

            push @results, $sth->execute($volume->get_packagetype(), $volume->get_namespace(), $volume->get_objid(), initial_priority($volume));
        } or print $@ and return \@results;
    }

    # set priorities for newly added volumes
    reprioritize(1);

    return \@results;
}

# reset(\@volumes, $force)
# 
# reset punted volumes, reset all volumes if $force
sub reset_volumes{
    my $volumes = shift;
    my $force = shift;
    
    my $dbh = HTFeed::DBTools::get_dbh();
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

1;

__END__

