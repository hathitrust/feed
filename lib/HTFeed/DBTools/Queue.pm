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

=item enqueue_volumes
enqueue volumes
=synopsis
enqueue_volumes($volume)
enqueue_volumes([$volume,...])
enqueue_volumes(
        (volume => $volume | volumes => ($volume,...),),
        status        => $status_string,
        ignore        => 1,
        use_blacklist => 0,
        priority      => $priority_modifier, # see Priority.pm for valid priority modifiers
)
=cut
# 
# add volumes to queue
sub enqueue_volumes{
    # accept hashless args
    if($#_ == 0){
       if ($_[0]->isa('HTFeed::Volume')){
           unshift(@_, 'volume');
       }
       else{
           unshift(@_, 'volumes');
       }
    }
    
    my %args = (
        volume        => undef,
        volumes       => undef,
        status        => undef,
        ignore        => undef,
        use_blacklist => 1,
        priority      => undef,
        @_
    );
    
    die q{Use 'volume' or 'volumes' arg, not both}
        if (defined $args{volume} and defined $args{volumes});
    
    my $volumes             = $args{volumes};
    $volumes = [$args{volume}]
        if (defined $args{volume});
    my $status              = $args{status};
    my $ignore              = $args{ignore};
    my $use_blacklist       = $args{use_blacklist};
    my $priority_modifier   = $args{priority};
    
    my $dbh = HTFeed::DBTools::get_dbh();
    my $sth;
    my $blacklist_sth = $dbh->prepare("SELECT namespace, id FROM feed_blacklist WHERE namespace = ? and id = ?");
    if($ignore){
        $sth = $dbh->prepare(q(INSERT IGNORE INTO feed_queue (pkg_type, namespace, id, priority, status) VALUES (?,?,?,?,?);));
    }else {
        $sth = $dbh->prepare(q(INSERT INTO feed_queue (pkg_type, namespace, id, priority, status) VALUES (?,?,?,?,?);));
    }
    
    my @results;
    foreach my $volume (@{$volumes}){
        eval{
            # First make sure volume is not on the blacklist.
            my $namespace = $volume->get_namespace();
            my $objid = $volume->get_objid();
            # use default first state from pkgtype def if not given one
            if(not defined $status) {
                $status = $volume->get_nspkg()->get('default_queue_state');
            }

            my $blacklisted = 0;
            if($use_blacklist) {
                $blacklist_sth->execute($namespace,$objid);
                if($blacklist_sth->fetchrow_array()) {
                    get_logger()->warn("Blacklisted",namespace=>$namespace,objid=>$objid);
                    push(@results,0);
                    $blacklisted = 1;
                }
            }

            if(!$blacklisted) {
                my $res = $sth->execute($volume->get_packagetype(), $volume->get_namespace(), $volume->get_objid(), initial_priority($volume,$priority_modifier), $status);
                push @results, $res;
            }
        };
        get_logger()->error($@) and return \@results if $@;
    }

    # set priorities for newly added volumes
    reprioritize(1);

    return \@results;
}

# reset_volumes(\@volumes, $force)
# 
# reset punted and done volumes, reset all volumes if $force
=item reset
reset volumes
=synopsis
reset_volumes($volume);
reset_volumes([$volume,...]);
reset_volumes(
        (volume => $volume | volumes => ($volume,...),),
        [force => 1]
        [status => $status]
);
=cut
sub reset_volumes {
    # accept hashless args
    if($#_ == 0){
       if ($_[0]->isa('HTFeed::Volume')){
           unshift(@_, 'volume');
       }
       else{
           unshift(@_, 'volumes');
       }
    }
    
    my %args = (
        volume  => undef,
        volumes => undef,
        force   => undef,
        status  => undef,
        @_
    );
    
    die q{Use 'volume' or 'volumes' arg, not both}
        if (defined $args{volume} and defined $args{volumes});
    
    my $volumes = $args{volumes};
    $volumes = [$args{volume}]
        if (defined $args{volume});

    my $force = $args{force};
    my $status = $args{status};
    
    my $dbh = HTFeed::DBTools::get_dbh();
    my $sth;
    if($force){
        $sth = $dbh->prepare(q(UPDATE feed_queue SET node = NULL, status = ?, failure_count = 0 WHERE namespace = ? and id = ?;));
    }
    else{
        $sth = $dbh->prepare(q(UPDATE feed_queue SET node = NULL, status = ?, failure_count = 0 WHERE status in ('punted','collated','rights','done') and namespace = ? and id = ?;));
    }
    
    my @results;
    foreach my $volume (@{$volumes}){
        # use default initial state from pkgtype def if not given one
        if(not defined $status) {
            $status = $volume->get_nspkg()->get('default_queue_state');
        }
        push @results, $sth->execute($status,$volume->get_namespace(), $volume->get_objid());
    }
    return \@results;
}

1;

__END__

