#!/usr/bin/perl

use strict;
use warnings;
use HTFeed::DBTools qw(get_dbh);
use Test::DatabaseRow;
use Test::More;

my @row;

#connect to DB
my $dbh = HTFeed::DBTools::get_dbh();
local $Test::DatabaseRow::dbh = $dbh;

#test that tables exist
my $table;
my @tables=("queue", "ingest_log");
my $test = 0;
my $row_count = 0;

for $table(@tables) {
	my $sth = $dbh->prepare("show tables");
	my $execute = $sth->execute;
	while (@row = $sth->fetchrow_array) {
		for my $row(@row) {
			if($row eq $table) {
				$row_count++;
			}
		}
	}
	if ($row_count == 1) {
		$test = $table;
	}
	is($test,$table,"table $table exists");
	$row_count--;
}

#test that colums exist

#test sql

done_testing();

__END__
