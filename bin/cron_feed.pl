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
    my $stage_info = $nspkg->get('stage_info');
    my $stage_name = $stage_map->{$status};
    my $stage_directions = $stage_info->{$stage_name};
    my $stage_class = $stage_directions->{class};
    my $stage = eval "$stage_class->new(volume => \$volume)";
    
    $stage->run();
    $stage->clean();
    
    # update_db
    my $new_status;
    if ($stage->succeeded()){
        $new_status = $stage_directions->{success_state};
    }else{
        $new_status = $stage_directions->{failure_state};
    }
    my $dbh = HTFeed::DBTools::get_dbh();
    my $sth = $dbh->prepare(q(UPDATE `queue` SET `status` = ? WHERE `ns` = ? AND `pkg_type` = ? AND `objid` = ?;));
    $sth->execute($new_status,$namespace,$packagetype,$objid);
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


