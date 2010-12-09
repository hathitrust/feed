#!/usr/bin/perl

=description
cron_feed.pl ingests packages
=cut

use warnings;
use strict;

use DBI;

use HTFeed::Config qw(get_config);
use HTFeed::Volume;
use HTFeed::Log;
use HTFeed::DBTools;

HTFeed::Log->init();

while(my $sth = get_queued(20)){
    while (my ($ns,$pkg_type,$objid,$status) = $sth->fetchrow_array()){
        run_stage($ns,$pkg_type,$objid,$status);
    }  
}

# run_stage($ns,$pkg_type,$objid,$status)
sub run_stage{
    my ($namespace,$packagetype,$objid,$status) = @_;

    my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);
    my $nspkg = $volume->get_nspkg();

    my $stage_map = $nspkg->get('stage_map');
    my $stage_class = $stage_map->{$status};

    my $stage = eval "$stage_class->new(volume => \$volume)";

    $stage->run();
    $stage->clean();

    # update_db
    my $new_status;
    if ($stage->succeeded()){
        $new_status = $stage->get_stage_info('success_state');
    }else{
        $new_status = $stage->get_stage_info('failure_state');
    }

    # update status if $new_status isn't blank (signifying that there should be no staus update)
    if ($new_status){
        my $dbh = HTFeed::DBTools::get_dbh();
        my $sth = $dbh->prepare(q(UPDATE `queue` SET `status` = ? WHERE `ns` = ? AND `pkg_type` = ? AND `objid` = ?;));
        $sth->execute($new_status,$namespace,$packagetype,$objid);
    }
}

# get_queued($number_of_items)
# return $sth, with rows containing (ns,pkg_type,objid,status)
# unless there are no items, then return false
sub get_queued{
    my $items = (shift or 1);
    
    my $dbh = HTFeed::DBTools::get_dbh();
    my $sth = $dbh->prepare(q(SELECT `ns`, `pkg_type`, `objid`, `status` FROM `queue` WHERE `status` NOT LIKE 'punted' AND `status` NOT LIKE 'collated' LIMIT ?;)); # ORDER BY ?
    $sth->execute($items);
    
    return $sth if ($sth->rows > 0);
    return;
}


