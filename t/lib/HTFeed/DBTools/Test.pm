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

sub test_disallow_list : Test(3) {
    # Ensure that the enqueue method refuses to add disallowed volumes

    # use something known to be on the disallow list
    my $dbh = HTFeed::DBTools::get_dbh();
    my $ns = 'test';
    my $objid = '39015002008244';

    $dbh->do("DELETE FROM feed_queue WHERE id = '$objid' and namespace = '$ns'");

    my @res = $dbh->selectrow_array("SELECT count(*) FROM feed_queue_disallow WHERE id = '$objid' and namespace = '$ns'");
    is($res[0],1,"presence of $ns.$objid in feed_queue_disallow");


    my $test_volume = new HTFeed::Volume(packagetype => 'simple',
        namespace => $ns,
        objid => $objid);

    my $results = enqueue_volumes($test_volume);

    is($results->[0],0,"enqueing disallowed volume $ns.$objid fails");

    @res = $dbh->selectrow_array("SELECT count(*) FROM feed_queue WHERE id = '$objid' and namespace = '$ns'");
    is($res[0],0,"volume $ns.$objid is not in queue");

}

sub test_queue : Test(3) {
    # Ensure that the enqueue method correctly adds a volume that is not on the disallow list
    my $dbh = HTFeed::DBTools::get_dbh();
    my $ns = 'test';
    my $objid = '35112102255835';

    $dbh->do("DELETE FROM feed_queue WHERE id = '$objid' and namespace = '$ns'");
    $dbh->do("REPLACE INTO feed_zephir_items (namespace, id, collection, digitization_source, returned) values ('$ns','$objid','MIU','google','0')");

    my @res = $dbh->selectrow_array("SELECT count(*) FROM feed_queue_disallow WHERE id = '$objid' and namespace = '$ns'");

    is($res[0],0,"non-presence of $ns.$objid in disallow list");

    my $test_volume = new HTFeed::Volume(packagetype => 'simple',
        namespace => $ns,
        objid => $objid);

    my $results = enqueue_volumes($test_volume);

    is($results->[0],1,"enqueing volume $ns.$objid succeeds");

    @res = $dbh->selectrow_array(<<EOT
        SELECT count(*) FROM feed_queue WHERE id = '$objid' and namespace = '$ns' 
EOT
    );
	#TODO check this
    is($res[0],1,"volume $ns.$objid is in queue with expected values");
}


1;

__END__
