#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use File::Basename;
use POSIX qw(strftime);


my $dbh = get_dbh();

my $insert="replace into fs_log (namespace, id, type, size, date) values(?,?,?,?,?);";
my $sth=$dbh->prepare($insert);

### set /sdr1 to /sdrX for test & parallelization
my $base= shift @ARGV or die("Missing base directory..");
my $filesProcessed = 0;
open(RUN, "find $base/obj/ -follow -type f|") or die ("Can't open pipe to find: $!");

while(my $file = <RUN>) {

    my @newList=(); #initialize array

    eval {
        $filesProcessed++;
        if($filesProcessed % 10000== 0) {
            print "$filesProcessed files processed\n";
        }
        chomp($file);
        my $size = -s $file;

        my ($barcode,$path,$type) =  fileparse($file,".mets.xml",".zip");
        # strip trailing / from path
        $path =~ s/\/$//;

        my @pathcomp = split("/",$path);

        # remove base & any empty components 
        @pathcomp = grep { $_ ne '' } @pathcomp;  
        shift @pathcomp; 
        my $namespace = $pathcomp[1];

        #get last modified date
        my $stat = (stat $file)[9];
        my $date= strftime("%Y-%m-%d %H:%M:%S",localtime((stat($file))[9]));

        #test symlinks
        my $link_path = join("/","/sdr1",@pathcomp);
        my $link_target = readlink $link_path or print("CANT_LSTAT $link_path $!\n");

        if($link_target ne $path) {
            print ("SYMLINK_INVALID $path $link_target\n");
        }

        #insert
        $sth->execute($namespace,$barcode,$type,$size,$date);


        # does barcode have a zip & xml, and do they match?
        opendir(my $dh, $path);

        my $filecount = 0;
        my $found_zip = 0;
        my $found_mets = 0;
        while( my $file = readdir($dh))  {
            next if $file eq '.' or $file eq '..';
            if($file !~ /^([^.]+)\.(zip|mets.xml)$/) {
                print("BAD_FILE $path $file\n");
            }
            my $dir_barcode = $1;
            my $ext = $2;
            $found_zip++ if $ext eq 'zip';
            $found_mets++ if $ext eq 'mets.xml';
            if($barcode ne $dir_barcode) { 
                print ("BARCODE_MISMATCH $barcode $dir_barcode\n");
            }
            $filecount++;
        }


        closedir($dh);

        #number files in dir
        if($filecount != 2 or $found_zip != 1 or $found_mets != 1) {
            print("BAD_FILECOUNT $barcode zip=$found_zip mets=$found_mets total=$filecount");
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
