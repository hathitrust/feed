#!/usr/bin/perl

use HTFeed::Namespace;
use strict;

my %nspkgs;

# Provide a list of HathiTrust IDs on standard input, e.g. mdp.39015012345678
# Prints whether the identifiers pass barcode validation or not.

while(my $line = <>) {
  chomp $line;
  my ($namespace,$id) = split(/\./,$line,2);
  die("Bad line: $line") unless $namespace and $id;

  my $nspkg;
  if(defined $nspkgs{$namespace}) {
    $nspkg = $nspkgs{$namespace};
  } else {
    $nspkg = HTFeed::Namespace->new($namespace,'ht');
    $nspkgs{$namespace} = $nspkg;
  }

  if($nspkg->validate_barcode($id)) {
    print "$line	OK\n";
  } else {
    print "$line	BAD\n";
  }
}
