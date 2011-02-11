#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use HTFeed::DBTools qw(get_dbh);
use Test::DatabaseRow;
use Test::More;

#connect to DB
my $dbh = HTFeed::DBTools::get_dbh();
local $Test::DatabaseRow::dbh = $dbh;

my $row = "39015000531544";
my $ns = "mdp";
my $table = "blacklist";
my $fakeNS = "foo";

#test success
row_ok(
	table	=> $table,
		where	=> [id => $row,
		namespace => $ns,],
	label	=> "$ns $row exists in table $table"
);

#test fail
row_ok(
	sql		=> "select * from $table where namespace = '$fakeNS'",
	results	=> 0,
	label	=> "$table does not contain namespace '$fakeNS'"
);

done_testing();

__END__
