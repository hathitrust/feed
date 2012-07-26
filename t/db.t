#!/usr/bin/perl

use strict;
use warnings;
use HTFeed::DBTools qw(get_dbh);
use Test::DatabaseRow;
use Test::More;

#connect to DB
my $dbh = HTFeed::DBTools::get_dbh();
local $Test::DatabaseRow::dbh = $dbh;
ok($dbh->ping, "database connection");

#test that tables exist
my $table;
my @tables=("queue", "log");
my @row;
my $match = "no match";

for $table(@tables) {
	my $sth = $dbh->prepare("show tables");
	my $execute = $sth->execute;
	while (@row = $sth->fetchrow_array) {
		for my $row(@row) {
			if($row eq $table) {
				$match = $table;
			}
		}
	}
	cmp_ok($match, 'eq', $table, "table $table exists");
	$match = "null";
}

#test columns
my $label;
$table = "queue";
my @cols = qw(pkg_type namespace id status update_stamp date_added node failure_count);
for my $col(@cols) {
	# grab aliases to a DB handle and a table name
	my $sth = $dbh->prepare("SELECT * FROM $table WHERE 1=0;");
	$sth->execute;
	my @labels = @{$sth->{NAME}};
	$sth->finish;

	for $label(@labels) {
		if($label eq $col) {
			$match = $col;
		}
	}
	cmp_ok($match, 'eq', $col, "column $col exists");
}

#test sql
my $execute;
eval{
	my $sth = $dbh->prepare("SELECT pkg_type, namespace, id, status, failure_count FROM queue WHERE node = ?");
	$execute = $sth->execute;
};
ok($execute, "correct syntax");

#test specific calls
row_ok(
	table	=>	"queue",
	where	=>	["status"	=> "punted"],
	label	=>	"db call valid",
);

done_testing();

__END__
