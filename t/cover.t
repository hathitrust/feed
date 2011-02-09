#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Devel::Cover;
use File::Basename;
use FindBin;

#code coverage for GROOVE 2.0

#get time stamp
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $date = sprintf("%4d-%02d-%02d", $year+1900,$mon+1,$mday);

my $tests   = "$FindBin::Bin/t";
my $home    = "$tests/coverage";
my $logs    = "$home/logs";
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

__END__

OUTDATED

my $testDir	= "/htapps/ezbrooks.babel/git/feed/t";
my $home	= "/$testDir/coverage";
my $logs	= "$home/logs";
my $newFile;
		next unless $ftype eq ".t";
		$newFile = "$name" . "_coverage_" . $date;
		chdir $home;
		`perl -MDevel::Cover $testDir/$file  -merge val > $logs/$newFile`;
		Devel::Cover::Test->new("$file");
		#TODO: dump output in logs using method
