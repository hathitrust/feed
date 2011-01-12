#!/usr/bin/perl

use strict;
use warnings;

use Cwd;
use Devel::Cover;
use File::Basename;

#current version checks ".t" files only, /feed/t only
#TODO:
# option to specify files by name and/or type
# option to specify directory
# store coverage controller elsewhere
# centralize location for coverage output

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $date = sprintf("%4d-%02d-%02d", $year+1900,$mon+1,$mday);

my $home	= "/htapps/ezbrooks.babel/git/feed/t/coverage";
my $testDir	= "/htapps/ezbrooks.babel/git/feed/t";
my $logs	= "$home/logs";
my $newFile;

#read dir, get files
chdir $testDir;
my @files = <*>;
foreach my $file (@files) {
	my($name, undef, $ftype) = fileparse($file,qr"\..*");
		next unless $ftype eq ".t";
		$newFile = "$name" . "_coverage_" . $date;
		chdir $home;
		`perl -MDevel::Cover $testDir/$file  -merge val > $logs/$newFile`;
}
