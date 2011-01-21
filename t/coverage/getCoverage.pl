#!/usr/bin/perl

use strict;
use warnings;

use Cwd;
use Devel::Cover;
use Devel::Cover::Test;

use File::Basename;

#checking ".t" files only, /feed/t only

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $date = sprintf("%4d-%02d-%02d", $year+1900,$mon+1,$mday);

my $testDir	= "/htapps/ezbrooks.babel/git/feed/t";
my $home	= "/$testDir/coverage";
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
		Devel::Cover::Test->new("$file");
		#TODO: dump output in logs using method
		
}
