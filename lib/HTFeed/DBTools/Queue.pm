package HTFeed::DBTools::Queue;

=description
    All queries for queue that are not in running ingest steps
    
=cut

use warnings;
use strict;
use Carp;
use base qw(HTFeed::DBTools);
use HTFeed::DBTools::Priority qw(reprioritize);

our @EXPORT = qw(enqueue_volumes reset_volumes);

# enqueue(\@volumes)
# 
# add volumes to queue
sub enqueue_volumes{
    my $volumes = shift;
    my $ignore = shift;
    
    my $dbh = HTFeed::DBTools::get_dbh();
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
    
    my $dbh = get_dbh();
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

