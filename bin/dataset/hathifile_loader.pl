#!/usr/bin/env perl

use HTFeed::DBTools;

my $update_sth = HTFeed::DBTools::get_dbh()->prepare('UPDATE feed_dataset_tracking SET pubdate = ? AND lang008 = ? WHERE namespace = ? AND id = ?');

for (<>) {
    chomp;
    my @fields = split("\t",$_);
    my $htid = $fields[0];
    my ($namespace,$id) = split(/\./,$htid,2);
    my $pubdate = $fields[16];
    my $lang008 = $fields[18];
    $update_sth->execute($pubdate,$lang008,$namespace,$id)
}