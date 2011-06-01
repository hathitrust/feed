package HTFeed::DBTools::Test;

use warnings;
use strict;

use base qw(HTFeed::Test::Class);
use Test::More;
use HTFeed::DBTools;
use HTFeed::DBTools::Queue;
use HTFeed::Volume;
use HTFeed::Namespace;
use HTFeed::PackageType;

sub test_blacklist : Test(3) {
    # Ensure that the enqueue method refuses to add blacklisted volumes

    my $dbh = HTFeed::DBTools::get_dbh();
    my $ns = 'mdp';
    my $objid = '39015000531544';

    $dbh->do("DELETE FROM queue WHERE id = '$objid' and namespace = '$ns'");

    my @res = $dbh->selectrow_array("SELECT count(*) FROM blacklist WHERE id = '$objid' and namespace = '$ns'");
    is($res[0],1,"presence of $ns.$objid in blacklist");


    my $test_volume = new HTFeed::Volume(packagetype => 'google',
        namespace => $ns,
        objid => $objid);

    my $results = enqueue_volumes([$test_volume]);

    is($results->[0],0,"enqueing blacklisted volume $ns.$objid fails");

    @res = $dbh->selectrow_array("SELECT count(*) FROM queue WHERE id = '$objid' and namespace = '$ns'");
    is($res[0],0,"volume $ns.$objid is not in queue");


}

sub test_queue : Test(3) {
    # Ensure that the enqueue method correctly adds a volume that is not on the blacklist
    my $dbh = HTFeed::DBTools::get_dbh();
    my $ns = 'mdp';
    my $objid = '35112102255835';

    $dbh->do("DELETE FROM queue WHERE id = '$objid' and namespace = '$ns'");

    my @res = $dbh->selectrow_array("SELECT count(*) FROM blacklist WHERE id = '$objid' and namespace = '$ns'");
    is($res[0],0,"non-presence of $ns.$objid in blacklist");


    my $test_volume = new HTFeed::Volume(packagetype => 'google',
        namespace => $ns,
        objid => $objid);

    my $results = enqueue_volumes([$test_volume]);

    is($results->[0],1,"enqueing volume $ns.$objid succeeds");

    @res = $dbh->selectrow_array(<<EOT
        SELECT count(*) FROM queue WHERE id = '$objid' and namespace = '$ns' 
            and node is NULL and status = 'ready' 
            and pkg_type = 'google' and failure_count = '0'
EOT
    );
    is($res[0],1,"volume $ns.$objid is in queue with expected values");
}


1;
__END__
