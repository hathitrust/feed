#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);

my $namespace;
my $type;
my $barcode;

my $dbh = get_dbh();

my $insert="replace into fs_log (namespace, id, type, size, date) values(?,?,?,?,?);";
my $sth=$dbh->prepare($insert);

### set /sdr1 to /sdrX for test & parallelization
my $base="sdr5";
my $filesProcessed = 0;
open(RUN, "find /$base/obj/ -follow -type f|") or die ("Can't open pipe to find: $!");

while(my $line = <RUN>) {

    my @newList=(); #initialize array

    #skip mdl/reflections for now (nonstandard mdl barcodes, causing parsing issues)
    next if $line =~ /reflect/; 

    eval {
        $filesProcessed++;
        if($filesProcessed % 10000== 0) {
            print STDERR "$filesProcessed files processed\n";
        }
        chomp($line);
        my $size = -s $line;

        if($line =~ m/\/$base\/obj\/(\w+)\//) {
            $namespace = $1;
        }

        if($line =~ m/\/([^\/.]+)\./) {
            $barcode = $1;
        }

        if ($line =~ m/([^\/.]+)\/([^\/.]+)\.(\w+)/) {    
            $type = $3;
        }

        #get last modified date
        my $stat = (stat $line)[9];
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($stat);
        my $date=substr($year+1900, -4) . '-' . substr('0'.($mon+1), -2) . '-' . substr('0'.$mday, -2) . ' ' . substr('0'.$hour, -2) . ':' . substr('0'.$min, -2) . ':' . substr('0'.$sec, -2);

        #test symlinks
        my $slice = length($barcode);
        my $root;
        if($type eq "mets") {
            $root = substr($line, 6, length($line)-($slice+16));
        } elsif($type eq "zip") {
            $root = substr($line, 6, length($line)-($slice+11));
        }

        my $check = "/sdr1/$root";
        my $sym= lstat $check;
        my $test="/".substr($line,(length($sym)-length($line)),length($line)-1);

        if($test ne $line) {
            warn("symlink not valid for $line\n");
        }

        #insert
        $sth->execute($namespace,$barcode,$type,$size,$date);

        # barcode/dir != zip || xml
        if ($type ne "zip" && $type ne "mets") {
            warn("Unexpected type $type for file $line\n");
        }

        # does barcode have a zip & xml, and do they match?
        my $dir1 = "/$base/obj/$namespace/pairtree_root/";
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

#            # check against ht_files
#			my $htCheck = "select * from ht_files where namespace='$namespace' and id='$barcode'";
#			my $sth2=$dbh->prepare($htCheck);
#			$sth2->execute();
#			# TODO:
#			# pipe output . . . to file?
#			# on error, warn . . .
        #
#            # check against rights_current
#			my $rightsCheck = "select * from mdp.rights_current where namespace='$namespace' and id='$barcode'";
#			my $sth3=$dbh->prepare($rightsCheck);
#            $sth3->execute();
#			# TODO:
#			# pipe output . . . to file?
#			# on error, warn . . .

    };

    if($@) {
        warn($@);
    }
}

$dbh->disconnect;
close(RUN);

__END__
