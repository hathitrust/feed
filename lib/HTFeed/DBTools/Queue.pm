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
    my $arg_status              = $args{status};
    my $ignore              = $args{ignore};
    my $use_blacklist       = $args{use_blacklist};
    my $priority_modifier   = $args{priority};
    
    my $dbh = HTFeed::DBTools::get_dbh();
    my $sth;
    my $blacklist_sth = $dbh->prepare("SELECT namespace, id FROM feed_blacklist WHERE namespace = ? and id = ?");
    my $digifeed_sth = $dbh->prepare("SELECT namespace, id FROM feed_mdp_rejects WHERE namespace = ? and id = ?");
    my $has_bibdata_sth = $dbh->prepare("SELECT namespace, id FROM feed_zephir_items WHERE namespace = ? and id = ?");
    my $return_sth = $dbh->prepare("UPDATE feed_zephir_items SET returned = '1' WHERE namespace = ? and id = ?");
    if($ignore){
        $sth = $dbh->prepare(q(INSERT IGNORE INTO feed_queue (pkg_type, namespace, id, priority, status) VALUES (?,?,?,?,?);));
    }else {
        $sth = $dbh->prepare(q(INSERT INTO feed_queue (pkg_type, namespace, id, priority, status) VALUES (?,?,?,?,?);));
    }
    
    my @results;
    foreach my $volume (@{$volumes}){
        eval{
            # First make sure volume has bib data
            # Then make sure volume is not on the blacklist.

            my $namespace = $volume->get_namespace();
            my $objid = $volume->get_objid();
            my $pkg_type = $volume->get_packagetype();
            my $status = $arg_status;
            # use default first state from pkgtype def if not given one
            if(not defined $status) {
                $status = $volume->get_nspkg()->get('default_queue_state');
            }

            my $has_bib_data = 0;
            $has_bibdata_sth->execute($namespace,$objid);
            if($has_bibdata_sth->fetchrow_array()) {
                $has_bib_data = 1;
            } else {
                get_logger()->warn("NoBibData",namespace=>$namespace,objid=>$objid);
                push(@results,0);
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

            # use list of 'mdp rejects' in determining whether to queue as digifeed
            # or google
            my $digifeed = 0;
            if($volume->get_packagetype() eq 'google' and $namespace eq 'mdp') {
                $digifeed_sth->execute($namespace,$objid);
                if($digifeed_sth->fetchrow_array()) {
                    $pkg_type = 'digifeed';
                }
            }

            if($has_bib_data and !$blacklisted) {
                my $res = $sth->execute($pkg_type, $namespace, $objid, initial_priority($volume,$priority_modifier), $status);
                push @results, $res;
                if($res) {
                  $res = $return_sth->execute($namespace,$objid);
                  push @results, $res;
                }
            }
        };
        get_logger()->error($@) and return \@results if $@;
    }

    # set priorities for newly added volumes
    reprioritize(1);

    return \@results;
}

# reset_volumes(\@volumes, $reset_level)
# 
# reset punted and done volumes. reset level determines which:
#  0: nothing
#  1: punted
#  2: punted, collated, rights, done
#  3: everything (including "in-flight" volumes; use with care)
=item reset
reset volumes
=synopsis
reset_volumes($volume,reset_level => $reset_level);
reset_volumes([$volume,...],reset_level => $reset_level);
reset_volumes(
        (volume => $volume | volumes => ($volume,...),),
        [force => 1]
        [status => $status]
        [reset_level => $reset_level]
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
        reset_level   => undef,
        status  => undef,
        @_
    );
    
    die q{Use 'volume' or 'volumes' arg, not both}
        if (defined $args{volume} and defined $args{volumes});

    die "Reset level should be >0 and <=3" if not defined $args{reset_level} or $args{reset_level} < 1 or $args{reset_level} > 3;
    
    my $volumes = $args{volumes};
    $volumes = [$args{volume}]
        if (defined $args{volume});

    my $reset_level = $args{reset_level};
    my $status = $args{status};
    
    my $dbh = HTFeed::DBTools::get_dbh();
    my $sth;
    if($reset_level == 3){
        $sth = $dbh->prepare(q(UPDATE feed_queue SET node = NULL, status = ?, failure_count = 0 WHERE namespace = ? and id = ?;));
    } else {
        my $statuses = "";
        $statuses = "('punted')" if $reset_level == 1;
        $statuses = "('punted','collated','rights','done')" if $reset_level == 2;
        $sth = $dbh->prepare(qq(UPDATE feed_queue SET node = NULL, status = ?, failure_count = 0 WHERE status in $statuses and namespace = ? and id = ? and node is null;));
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

