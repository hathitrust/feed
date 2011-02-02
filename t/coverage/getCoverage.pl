#!/usr/bin/perl

use strict;
use warnings;

use Cwd;
use Devel::Cover;
use Devel::Cover::Test;
use FindBin;
use File::Basename;

#get time stamp
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $date = sprintf("%4d-%02d-%02d", $year+1900,$mon+1,$mday);

my $tests	= "$FindBin::Bin/t";
my $home	= "$tests/coverage";
my $logs	= "$home/logs";
my $cover;

#read dir, get files
chdir $tests;
my @files = <*>;
foreach my $file (@files) {
	my($name, undef, $ftype) = fileparse($file,qr"\..*");
		next unless $ftype eq ".t";
		$cover = "$name" . "_coverage_" . $date;
		chdir $home;
		Devel::Cover::Test->new("$file");
		#TODO: dump output in logs using method
		# use option to merge cover_db into one centralized location
		
}
