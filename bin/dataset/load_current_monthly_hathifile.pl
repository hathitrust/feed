#!/usr/bin/env perl

use File::Basename;
my $bin = dirname(__FILE__);

my ($sec,$min,$hour,$mday,$mon,$year) = localtime;
$year +=1900; $mon++;

my $tmpdir = '/tmp/feed/hathifiles';
my $get_full_cmd = sprintf('wget http://www.hathitrust.org/sites/www.hathitrust.org/files/hathifiles/hathi_full_%d%02d04.txt.gz',$year,$mon,$mday);

system("mkdir -p $tmpdir");
system("cd $tmpdir; $get_full_cmd");
system("zcat $tmpdir/hathi_*.txt.gz | $bin/hathifile_loader.pl");
system("rm -rf $tmpdir");
