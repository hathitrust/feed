#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Encode qw(encode);
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

subtest "UTF-8 support for ht_rights" => sub {
  my @tables = ('rights_current', 'rights_log');
  foreach my $table (@tables) {
    clean_utf8_test($table);
    my $sql = "INSERT INTO $table (namespace,id,attr,reason,source,access_profile,user,note)" .
              " VALUES ('utf8test','0',2,1,1,1,'libadm','慶應義塾大')";
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    $sth = $dbh->prepare("SELECT note FROM $table WHERE namespace=? AND id=?");
    $sth->execute('utf8test', '0');
    my @row = $sth->fetchrow_array;
    $sth->finish;
    is($row[0], encode('UTF-8', "慶應義塾大"), "UTF-8 round-trip in $table.note");
    $sth = $dbh->prepare("SELECT COUNT(*) FROM $table WHERE note='慶應義塾大'");
    $sth->execute;
    @row = $sth->fetchrow_array;
    is($row[0], 1, "Can find $table.note with UTF-8 value.");
    clean_utf8_test($table);
  }

  sub clean_utf8_test {
    my $table = shift;

    my $sth = $dbh->prepare("DELETE FROM $table WHERE namespace=? AND id=?");
    $sth->execute('utf8test', '0');
  }
};

done_testing();

__END__
