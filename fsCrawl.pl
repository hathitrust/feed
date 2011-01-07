#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use File::Basename;
use File::Pairtree;
use HTFeed::Volume;
use POSIX qw(strftime);


my $insert="replace into fs_log (namespace, id, zip_size, zip_date, mets_size, mets_date, lastchecked, zipcheck_ok) values(?,?,?,?,?,?,CURRENT_TIMESTAMP,NULl);";
my $update="update fs_log set zipcheck_ok = ? where namespace = ? and id = ?";
my $status_ins = "insert into fs_log_status (namespace, id, path, status, detail) values (?,?,?,?,?)";

### set /sdr1 to /sdrX for test & parallelization
my $base= shift @ARGV or die("Missing base directory..");
my $filesProcessed = 0;
my $prevpath;
open(RUN, "find $base/obj/ -follow -type f|") or die ("Can't open pipe to find: $!");

while(my $line = <RUN>) {

    my @newList=(); #initialize array

    eval {
        $filesProcessed++;
        if($filesProcessed % 10000== 0) {
            print "$filesProcessed files processed\n";
        }
        chomp($line);

        # strip trailing / from path
        my ($pt_objid,$path,$type) =  fileparse($line,".mets.xml",".zip");
        $path =~ s/\/$//; # remove trailing /
        return if($prevpath and $path eq $prevpath);
        $prevpath = $path;

        my @pathcomp = split("/",$path);

        # remove base & any empty components 
        @pathcomp = grep { $_ ne '' } @pathcomp;  
        shift @pathcomp; 
        my $namespace = $pathcomp[1];

        my $objid = ppath2id($path);
        if($pt_objid ne s2ppchars($objid)) {
            set_status($namespace,$objid,$path,"BAD_PAIRTREE", "$objid $pt_objid");
        }

        #get last modified date
        my $zipfile = "$path/$pt_objid.zip";
        my $metsfile = "$path/$pt_objid.mets.xml";
        my $zipdate= strftime("%Y-%m-%d %H:%M:%S",localtime((stat($zipfile))[9]));
        my $metsdate= strftime("%Y-%m-%d %H:%M:%S",localtime((stat($metsfile))[9]));
        my $zipsize = -s $zipfile;
        my $metssize = -s $metsfile;

        #test symlinks
        my $link_path = join("/","/sdr1",@pathcomp);
        my $link_target = readlink $link_path or set_status($namespace,$objid,$path,"CANT_LSTAT", "$link_path $!");

        if($link_target ne $path) {
            set_status($namespace,$objid,$path,"SYMLINK_INVALID",$path,$link_target);
        }

        #insert
        execute_stmt($insert,$namespace,$objid,$zipsize,$zipdate,$metssize,$metsdate);


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
            if($pt_objid ne $dir_barcode) { 
                set_status($namespace,$objid,$path,"BARCODE_MISMATCH","$pt_objid $dir_barcode");
            }
            $filecount++;
        }


        closedir($dh);

        #number files in dir
        if($filecount != 2 or $found_zip != 1 or $found_mets != 1) {
            set_status($namespace,$objid,$path,"BAD_FILECOUNT","zip=$found_zip mets=$found_mets total=$filecount");
        }

        eval {
            if( zipcheck($namespace,$objid) ){
                execute_stmt($update,"1",$namespace,$objid);
            } else {
                execute_stmt($update,"0",$namespace,$objid);
            }
        };
        if($@) {
            set_status($namespace,$objid,$path,"CANT_ZIPCHECK",$@);
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


sub zipcheck {
    my ($namespace,$objid) = @_;

    # use google as a 'default' namespace for now
    my $volume = new HTFeed::Volume(packagetype => "google",namespace => $namespace,objid => $objid);
    my $mets = $volume->get_repos_mets_xpc();

    # Extract the checksum for the zip file that looks kind of like this:
    #  <METS:fileGrp ID="FG1" USE="zip archive">
    #     <METS:file ID="ZIP00000001" MIMETYPE="application/zip" SEQ="00000001" CREATED="2008-11-22T20:07:28" SIZE="30844759" CHECKSUM="42417b735ae73a3e16d1cca59c7fac08" CHECKSUMTYPE="MD5">
    #       <METS:FLocat LOCTYPE="OTHER" OTHERLOCTYPE="SYSTEM" xlink:href="39015603581748.zip" />
    #     </METS:file>
    #  </METS:fileGrp>

    my $zipname = $volume->get_zip();
    my $mets_zipsum = $mets->findvalue("//mets:file[mets:FLocat/\@xlink:href='$zipname']/\@CHECKSUM");

    if(not defined $mets_zipsum or length($mets_zipsum) ne 32) {
        set_status($namespace,$objid,$volume->get_repository_mets_path(),"MISSING_METS_CHECKSUM",undef);
        return;
    } else {
        my $realsum = HTFeed::VolumeValidator::md5sum($volume->get_repository_zip_path());
        if($mets_zipsum eq $realsum) {
            print "$zipname OK\n";
            return 1;
        } else {
            set_status($namespace,$objid,$volume->get_repository_zip_path(),"BAD_CHECKSUM","expected=$mets_zipsum actual=$realsum");
            return;
        }
    }
}

sub set_status {
    warn(join(" ",@_), "\n");
    execute_stmt($status_ins,@_);
}

sub execute_stmt {
    my $stmt = shift;
    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt);
    $sth->execute(@_);
}

get_dbh()->disconnect();
close(RUN);

__END__
