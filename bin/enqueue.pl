#!/usr/bin/perl

use warnings;
use strict;
use HTFeed::DBTools;
use HTFeed::Volume;

my $in_file = shift;

if (!$in_file or $in_file eq '-h' or !-f $in_file){
    print "usage: enqueue_volumes.pl volume_list.txt\n";
    exit;
}

open INFILE, '<', $in_file or die $!;

my @volumes;
while (<INFILE>) {
    my ($packagetype, $namespace, $objid) = split;
    unless( $packagetype and $namespace and $objid ){
        die "Bad infile syntax near: $_";
    }

    push @volumes, HTFeed::Volume->new(packagetype => $packagetype, namespace => $namespace, objid => $objid);
    #print "found: $packagetype $namespace $objid";
}

HTFeed::DBTools::enqueue(\@volumes);

__END__
=Synopsis
enqueue_volumes.pl volume_list.txt

volume_list contains rows like this:
packagetype namespace objid
=cut

