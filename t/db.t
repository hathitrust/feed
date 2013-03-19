#!/usr/bin/perl

use strict;
use warnings;
use HTFeed::DBTools qw(get_dbh);
use Test::More;

#connect to DB
my $dbh = HTFeed::DBTools::get_dbh();
ok($dbh->ping, "database connection");

#test that tables exist
my $table;
my @tables=("feed_queue", "feed_log", "feed_premis_events");
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

my %tables = (
    'feed_queue' => [qw(pkg_type namespace id status reset_status update_stamp date_added node failure_count priority)],
    'feed_log' => [qw(level timestamp namespace id operation message file field actual expected detail stage)],
    'feed_premis_events' => [qw(namespace id eventtype_id date outcome eventid custom_xml)],
);

while (my ($table,$columns) = each(%tables)) {
	# grab aliases to a DB handle and a table name
	my $sth = $dbh->prepare("SELECT * FROM $table WHERE 1=0;");
	$sth->execute;
	my @labels = @{$sth->{NAME}};
	$sth->finish;

    foreach my $col (@$columns) {
        ok( (grep {$_ eq $col} @labels), "table $table has column $col");
    }
}

#test sql
my $execute;
eval{
	my $sth = $dbh->prepare("SELECT pkg_type, namespace, id, status, failure_count FROM feed_queue WHERE node = ?");
	$execute = $sth->execute;
};
ok($execute, "correct syntax");

done_testing();

__END__
