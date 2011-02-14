#!/usr/bin/perl

use strict;
use warnings;
use HTFeed::DBTools qw(get_dbh);
use Test::DatabaseRow;
use Test::More;

#connect to DB
my $dbh = HTFeed::DBTools::get_dbh();
local $Test::DatabaseRow::dbh = $dbh;

my $row = "39015000531544";
my $ns = "mdp";
my $table = "blacklist";

row_ok(
	table	=> $table,
		where	=> [id => $row,
					namespace => $ns,],
	label	=> "$ns $row exists in table $table"
);

done_testing();

__END__
