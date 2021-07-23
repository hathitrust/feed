#!/usr/bin/perl
use strict;
use warnings;

die 'no arg' unless scalar @ARGV == 1;

fs_crawl($ARGV[0]);

sub fs_crawl {
  my $path = shift;

  $path .= '/' unless $path =~ m/\/$/;
  my $d;
  unless (opendir($d, $path)) {
    print STDERR "Can't open directory $path: $!\n";
    return;
  }
  my @entries = readdir($d); 
  closedir($d);
  @entries = sort @entries;
  while (my $f = shift @entries) {
    next if $f eq '.' || $f eq '..';
    if (-d $path . $f) {
      fs_crawl($path . $f);
    } elsif (-f $path . $f) {
      print "$path$f\n";
    }
  }
}
