#!/usr/bin/perl

use strict;
use HTFeed::DBTools;
use HTFeed::Config qw(get_config);
use Date::Manip;
# Generate the ingest log and barcode list on a daily basis for Tim

# Generate the ingest log and barcodes for this date
my $date = shift @ARGV;
# if no date given, use yesterday by default

if(not defined $date) {
    $date = UnixDate(ParseDate("yesterday"),"%Y-%m-%d");
}

my $barcode_log = sprintf(get_config("rights","barcode_deposit_template"),$date);

# first generate ingest log, broken out by namespace
my $dbh = HTFeed::DBTools::get_dbh();

my $namespaces = $dbh->selectall_arrayref("select distinct namespace from ingest_log where date(update_stamp) = '$date'");

foreach my $namespace_row (@$namespaces) {
    my $namespace = shift @$namespace_row;
    my $ingest_log = sprintf(get_config("ingest_report"),$namespace,$date);
    open(my $fh,">",$ingest_log) or die("Can't open $ingest_log: $!");
    my $sth = $dbh->prepare("select namespace,id,update_stamp,status,isrepeat,fatal from ingest_log where date(update_stamp) = ? and namespace = ?");
    $sth->execute($date,$namespace);
    while(my $row = $sth->fetchrow_arrayref()) {
        my @rowvals = map { defined $_ ? $_ : " " } @$row;
        my $namespace = shift @rowvals;
        my $objid = shift @rowvals;
        print $fh "$namespace.$objid," . join(",",@rowvals), "\n";
    }
    close($fh);
}

# then generate barcodes awaiting rights

open(my $fh,">>",$barcode_log) or die("can't open $barcode_log: $!");
$dbh->begin_work();

my $sth = $dbh->prepare("select ns,objid from queue where status = 'collated' and date(update_stamp) <= ?");
my $usth = $dbh->prepare("update queue set status = 'rights' where ns = ? and objid = ?");
$sth->execute($date);
while(my $row = $sth->fetchrow_arrayref()) {
    print $fh join(".",@$row), "\n";
    $usth->execute(@$row);
}

close($fh);

$dbh->commit();



