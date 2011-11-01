#!/usr/bin/perl

# prints id list for current full_set
## TODO: add options as needed

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use HTFeed::DBTools qw(get_dbh);

my $sth = get_dbh()->prepare(q{SELECT CONCAT(CONCAT(namespace,'.'),id) as htid FROM `dataset_tracking` WHERE delete_t IS NULL ORDER BY htid;});
$sth->execute();

while(my ($htid) = $sth->fetchrow_array()){
    print "$htid\n";
}

