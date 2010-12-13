#!/usr/bin/perl

=description
cron_feed.pl ingests packages
=cut

use warnings;
use strict;

use DBI;

use HTFeed::Config qw(get_config);
use HTFeed::Volume;
use HTFeed::Log {root_logger => 'INFO, dbi'};
use HTFeed::DBTools;

use Log::Log4perl qw(get_logger);

my $failure_limit = get_config('failure_limit');
my $volumes_in_process_limit = get_config('volumes_in_process_limit');

while(HTFeed::DBTools::lock_volumes($volumes_in_process_limit) or HTFeed::DBTools::count_locks()){
    while(my $sth = HTFeed::DBTools::get_queued()){
        while (my ($ns,$pkg_type,$objid,$status,$failure_count) = $sth->fetchrow_array()){
            run_stage($ns,$pkg_type,$objid,$status,$failure_count);
        }
    }
}

# run_stage($ns,$pkg_type,$objid,$status,$failure_count)
sub run_stage{
    my ($namespace,$packagetype,$objid,$status,$failure_count) = @_;

    my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);
    my $nspkg = $volume->get_nspkg();

    my $stage_map = $nspkg->get('stage_map');
    my $stage_class = $stage_map->{$status};

    my $stage = eval "$stage_class->new(volume => \$volume)";

    #print STDERR "Running stage ". ref($stage) . " on $namespace.$objid..";
    $stage->run();
    $stage->clean();

    # update queue table with new status and failure_count
    my $sth;
    if ($stage->succeeded()){
        $status = $stage->get_stage_info('success_state');
	    ##print STDERR "OK\n";
        $sth = HTFeed::DBTools::get_dbh()->prepare(q(UPDATE `queue` SET `status` = ? WHERE `ns` = ? AND `pkg_type` = ? AND `objid` = ?;));
    }else{
        my $new_status = $stage->get_stage_info('failure_state');
        $status = $new_status if ($new_status);
	    ##print STDERR "Failed\n";
	    $status = 'punted' if ($failure_count >= $failure_limit);
        $sth = HTFeed::DBTools::get_dbh()->prepare(q(UPDATE `queue` SET `status` = ?, failure_count=failure_count+1 WHERE `ns` = ? AND `pkg_type` = ? AND `objid` = ?;));
    }
    $sth->execute($status,$namespace,$packagetype,$objid);
}
