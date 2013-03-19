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

my $sth;
if($dbh->{Driver}->{Name} eq 'mysql') {
    $sth = $dbh->prepare("show tables");
} elsif($dbh->{Driver}->{Name} eq 'SQLite') {
    $sth = $dbh->prepare('SELECT name FROM sqlite_master WHERE type = "table";');
} else {
    die("Unsupported driver $dbh->{Driver}->{Name}");
}
ok($sth->execute,"fetch tables");

my @db_tables = ();
while (@row = $sth->fetchrow_array) {
    push(@db_tables,$row[0]);
}

foreach my $table (@tables) {
    ok( (grep {$_ eq $table} @db_tables), "table $table exists");
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
