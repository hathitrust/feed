#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use DBI;

my $date;
my $size;
my $sth;
my $total;
my $type;
my $line;
my $namespace;
my $barcode;
my $dbh;
my $file;
my @newList;

#TODO: set up config for db creds
my $db = "";
my $host="";
my $user="";
my $password="";

#establish mysql connection
$dbh = DBI->connect("DBI:mysql:database=$db:host=$host",$user,$password)
	or die ("Can't connect to the database: $!");


# set /sdr1 to /sdrX for multiple runs
open(RUN, "find /sdr1/obj/ -follow -type f|")
	or die ("Can't open pipe to find: $!");

while($line = <RUN>) {

	@newList=(); #initialize array
	#skip mdl/reflections fornow (nonstandard barcodes, causing parsing issues)
	next if $line =~ /reflect/; 
	
	while($retried < $maxretries) {
		eval {
			chomp($line);
			$size = -s $line;

			if($line =~ m/\/sdr1\/obj\/(.*?)\//) {
				$namespace = $1;
			}

			if($line =~ m/\/(\w+)\./) {
				$barcode = $1;
			}

			if ($line =~ m/(\w+)\/(\w+)\.(\w+)/) {    
				$type = $3;
			}

			#get last modified date
			my $stat = (stat $line)[9];
			my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($stat);
			$date=substr($year+1900, -4) . '-' . substr('0'.($mon+1), -2) . '-' . substr('0'.$mday, -2) . ' ' . substr('0'.$hour, -2) . ':' . substr('0'.$min, -2) . ':' . substr('0'.$sec, -2);

			my $insert="insert into fs_log (namespace, id, type, size, date) values('$namespace', '$barcode', '$type', '$size', '$date');";
			$sth=$dbh->prepare($insert);
			$sth->execute();

			# barcode/dir != zip || xml
			if ($type ne "zip" && $type ne "mets") {
				warn("Unexpected type $type for file $line\n");
			}

			# does barcode have a zip & xml, and do they match?
			my $dir1 = "/sdr1/obj/$namespace/pairtree_root/";
			my $code = $barcode;
			$barcode =~ s/(..)/$1\//g;
			my $dir2 = $dir1 . $barcode . $code;
			opendir(DIR, $dir2);
			my @files =  readdir(DIR);
			my $file;
			for $file(@files) {
        		next if $file =~ /^\./;
        		push @newList, $file;
			}

			my $newList;
			for $newList(@newList) {
				my $sub = substr($newList,-3,3);
				if($sub ne "zip" && $sub ne "xml") {
				    warn("Unexpected type $type for file $line\n");
				}
			}

			#number files in dir
			my $count= $#newList+1;
			if($count != 2) {
				warn("Unexpected filecount for barcode $code\n");
			}

			# are the barcodes of the files identical? (and do they match the current barcode?)
			my $newBar;
			for $newList(@newList) {
				if (substr($newList, -3) eq "zip") {
					$newBar = substr($newList, 0, length($newList)-4);
				} else {
					$newBar = substr($newList, 0, length($newList)-9);
				}
				if($newBar ne $code) {
					warn("Unexpected barcode mismatch for file $line\n");
				}
			}

            # validate barcodes for namespace consistency
			# my $capName = uc($namespace);
			# call validator? --> "/htapps/ezbrooks.babel/git/feed/lib/HTFeed/Namespace/$capName.pm"
			# pass $barcode --> pipe results to log file?

            # check against ht_files
			my $htCheck = "select * from ht_files where namespace='$namespace' and id='$barcode'";
			my $sth2=$dbh->prepare($htCheck);
			$sth2->execute();
			# TODO:
			# pipe output . . . to file?
			# on error, warn . . .

            # check against rights_current
			my $rightsCheck = "select * from mdp.rights_current where namespace='$namespace' and id='$barcode'";
			my $sth3=$dbh->prepare($rightsCheck);
            $sth3->execute();
			# TODO:
			# pipe output . . . to file?
			# on error, warn . . .

		};

		if($@) {
			warn($@);
		}
	}
}

$dbh->disconnect;
close(RUN);

__END__
