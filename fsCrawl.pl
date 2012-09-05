#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use File::Basename;
use File::Pairtree qw(ppath2id s2ppchars);
use HTFeed::Volume;
use HTFeed::Namespace;
use HTFeed::PackageType;
use HTFeed::METS;
use POSIX qw(strftime);
use Getopt::Long;


my $insert="replace into audit (namespace, id, zip_size, zip_date, mets_size, mets_date, lastchecked, zipcheck_ok) values(?,?,?,?,?,?,CURRENT_TIMESTAMP,NULL)";
my $update="update audit set zipcheck_ok = ? where namespace = ? and id = ?";
#my $fs_mets_data="insert into audit_mets_data (namespace, id, `key`, value, value2, date) values (?,?,?,?,?,CURRENT_TIMESTAMP)";
my $mets_ins = "insert into audit_detail (namespace, id, path, status, detail) values (?,?,?,?,?)";

### set /sdr1 to /sdrX for test & parallelization
my $filesProcessed = 0;
my $prevpath;
my $do_md5 = 0;
my $do_mets = 0;
GetOptions(
    'md5!' => \$do_md5,
    'mets!' => \$do_mets,
);

my $base= shift @ARGV or die("Missing base directory..");
open(RUN, "find $base -follow -type f|") or die ("Can't open pipe to find: $!");

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
        my $first_path = shift @pathcomp; 
        my $last_path = pop @pathcomp;
        my $namespace = $pathcomp[1];

        my $objid = ppath2id(join("/",@pathcomp));
        if($pt_objid ne s2ppchars($objid)) {
            set_status($namespace,$objid,$path,"BAD_PAIRTREE", "$objid $pt_objid");
        }

        if($last_path ne $pt_objid) {
            set_status($namespace,$objid,$path,"BAD_PAIRTREE", "$last_path $pt_objid");
        }

        #get last modified date
        my $zipfile = "$path/$pt_objid.zip";
        my $metsfile = "$path/$pt_objid.mets.xml";
        my $zipdate= strftime("%Y-%m-%d %H:%M:%S",localtime((stat($zipfile))[9]));
        my $metsdate= strftime("%Y-%m-%d %H:%M:%S",localtime((stat($metsfile))[9]));
        my $zipsize = -s $zipfile;
        my $metssize = -s $metsfile;

        #test symlinks unless we're traversing sdr1
        if($first_path ne 'sdr1') {
            my $link_path = join("/","/sdr1",@pathcomp,$last_path);
            my $link_target = readlink $link_path or set_status($namespace,$objid,$path,"CANT_LSTAT", "$link_path $!");

            if($link_target ne $path) {
                set_status($namespace,$objid,$path,"SYMLINK_INVALID",$link_target);
            }
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

    return unless $do_md5 or $do_mets;

    # use google as a 'default' namespace for now
    my $volume = new HTFeed::Volume(packagetype => "pkgtype",namespace => $namespace,objid => $objid);
    my $mets = $volume->get_repository_mets_xpc();
    my $rval = undef;

    # Extract the checksum for the zip file that looks kind of like this:
    #  <METS:fileGrp ID="FG1" USE="zip archive">
    #     <METS:file ID="ZIP00000001" MIMETYPE="application/zip" SEQ="00000001" CREATED="2008-11-22T20:07:28" SIZE="30844759" CHECKSUM="42417b735ae73a3e16d1cca59c7fac08" CHECKSUMTYPE="MD5">
    #       <METS:FLocat LOCTYPE="OTHER" OTHERLOCTYPE="SYSTEM" xlink:href="39015603581748.zip" />
    #     </METS:file>
    #  </METS:fileGrp>

    if($do_md5) {
        my $zipname = $volume->get_zip_filename();
        my $mets_zipsum = $mets->findvalue("//mets:file[mets:FLocat/\@xlink:href='$zipname']/\@CHECKSUM");

        if(not defined $mets_zipsum or length($mets_zipsum) ne 32) {
            set_status($namespace,$objid,$volume->get_repository_mets_path(),"MISSING_METS_CHECKSUM",undef);
        } else {
            my $realsum = HTFeed::VolumeValidator::md5sum($volume->get_repository_zip_path());
            if($mets_zipsum eq $realsum) {
                print "$zipname OK\n";
                $rval= 1;
            } else {
                set_status($namespace,$objid,$volume->get_repository_zip_path(),"BAD_CHECKSUM","expected=$mets_zipsum actual=$realsum");
            }
        }
    }

    if($do_mets) {
        # extract other stuff from repo METS
        { # File types & count
            my %filetypes;
            foreach my $file ($mets->findnodes('//mets:file/mets:FLocat/@xlink:href')) {
                my ($extension) = ($file->value =~ /\.(\w+)$/);
                $filetypes{$extension}++;
            }
            while(my ($ext,$count) = each(%filetypes)) {
                mets_ins($namespace,$objid,"FILETYPE",$ext,$count);
            }
        }

        { # PREMIS & premis ID version
            my $premisversion = "none";
            if($mets->findnodes('//mets:mdWrap[@MDTYPE="PREMIS"]')) {
                $premisversion = "unknown";
            }
            if($mets->findnodes('//mets:mdWrap//premis:premis')) {
                $premisversion = "premis2";
            }
            if($mets->findnodes('//mets:mdWrap//premis1:object')) {
                $premisversion = "premis1";
            }

            mets_ins($namespace,$objid,"PREMIS_VERSION",$premisversion);
        }

        { # PREMIS event ID types

            my %event_id_types = ();
            foreach my $eventtype ($mets->findnodes('//premis:eventIdentifierType | //premis1:eventIdentifierType')) {
                $event_id_types{$mets->findvalue('.',$eventtype)}++;
            }
            foreach my $event_id_type (keys(%event_id_types)) {
                mets_ins($namespace,$objid,"PREMIS_EVENT_TYPE",$event_id_type,$event_id_types{$event_id_type});
            }
        }

        { # PREMIS agent types
            my %agent_id_types = ();
            foreach my $agenttype ($mets->findnodes('//premis:linkingAgentIdentifierType | //premis1:linkingAgentIdentifierType')) {
                $agent_id_types{$mets->findvalue('.',$agenttype)}++;
            }
            foreach my $agent_id_type (keys(%agent_id_types)) {
                mets_ins($namespace,$objid,"PREMIS_AGENT_TYPE",$agent_id_type,$agent_id_types{$agent_id_type});
            }

        }

        { # Capturing agent
            foreach my $event ($mets->findnodes('//premis:event[premis:eventType="capture"] | //premis1:event[premis1:eventType="capture"]')) {
                my $executor = $mets->findvalue('./premis:linkingAgentIdentifier[premis:linkingAgentRole="Executor"]/premis:linkingAgentIdentifierValue |' .
                    './premis1:linkingAgentIdentifier/premis1:linkingAgentIdentifierValue',$event);
                my $date = $mets->findvalue('./premis:eventDateTime | ./premis1:eventDateTime',$event);
                mets_ins($namespace,$objid,"CAPTURE",$executor,$date);
            }
        }
        { # Processing agent
            foreach my $event ($mets->findnodes('//premis:event[premis:eventType="message digest calculation"] | //premis1:event[premis1:eventType="message digest calculation"]')) {
                my $executor = $mets->findvalue('./premis:linkingAgentIdentifier[premis:linkingAgentRole="Executor"]/premis:linkingAgentIdentifierValue |' .
                    './premis1:linkingAgentIdentifier/premis1:linkingAgentIdentifierValue',$event);
                my $date = $mets->findvalue('./premis:eventDateTime | ./premis1:eventDateTime',$event);
                mets_ins($namespace,$objid,"MD5SUM",$executor,$date);
            }
        }

        { # Ingest date
            foreach my $event ($mets->findnodes('//premis:event[premis:eventType="ingestion"] | //premis1:event[premis1:eventType="ingestion"]')) {
                my $date = $mets->findvalue('./premis:eventDateTime | ./premis1:eventDateTime',$event);
                mets_ins($namespace,$objid,"INGEST",$date);
            }
        }


        { # MARC present
            my $marc_present = $mets->findvalue('count(//marc:record | //record)');
            mets_ins($namespace,$objid,"MARC",$marc_present);
        }

        { # METS valid
            my ($mets_valid, $error) = HTFeed::METS::validate_xml({ volume => $volume },$volume->get_repository_mets_path());
            if(!$mets_valid) {
                $error =~ s/\n/ /mg;
            }

            mets_ins($namespace,$objid,"METS_VALID",$mets_valid,$error);
        }

        {
            eval {
                my %mdsecs = ();
                foreach my $mdsec ( $mets->findnodes('//mets:mdWrap | //mets:mdRef') ) {
                    my @mdbits = ();
                    push(@mdbits,$mdsec->nodeName);
                    foreach my $attr (qw(LABEL MDTYPE OTHERMDTYPE)) {
                        my $attrval = $mdsec->getAttribute($attr);
                        if($attrval and $attrval ne '') {
                            push(@mdbits,"$attr=$attrval");
                        }
                    }
                    mets_ins($namespace,$objid,"METS_MDSEC",join("; ",@mdbits));
                }
            }
        }

        { # Page tagging
            my $has_pagetags = $mets->findvalue('count(//mets:div[@TYPE="page"]/@LABEL[string() != ""])');
            mets_ins($namespace,$objid,"PAGETAGS",$has_pagetags);
            my $pages = $mets->findvalue('count(//mets:div[@TYPE="page"])');
            mets_ins($namespace,$objid,"PAGES",$pages);
        }


        extract_source_mets($volume);
    }
    return $rval;
}

sub set_status {
    warn(join(" ",@_), "\n");
    execute_stmt($mets_ins,@_);
}

sub execute_stmt {
    my $stmt = shift;
    my $dbh = get_dbh();
    my $sth = $dbh->prepare($stmt);
    $sth->execute(@_);
}

sub extract_source_mets {
    my $volume = shift;
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my $zipfile = $volume->get_repository_zip_path();
    my $pt_objid = $volume->get_pt_objid();
    my @srcmets = ();

    open(my $zipinfo,"unzip -l '$zipfile'|");
    while(<$zipinfo>) {
        chomp;
        my @zipfields = split /\s+/;
        if($zipfields[4] and $zipfields[4] =~ /^\Q$pt_objid\E\/\w+_\Q$pt_objid\E.xml/i) {
            push(@srcmets,$zipfields[4]);
        }
    }
    if(!@srcmets) {
        set_status($namespace,$objid,$zipfile,"NO_SOURCE_METS",undef);
    } elsif(@srcmets != 1) {
        set_status($namespace,$objid,$zipfile,"MULTIPLE_SOURCE_METS_CANDIDATES",undef);
    } else {
        # source METS found
        mets_ins($namespace,$objid,"SOURCE_METS",$srcmets[0]);
        system("cd /tmp; unzip -j '$zipfile' '$srcmets[0]'");
        my ($smets_name) = ($srcmets[0] =~ /\/([^\/]+)$/);
        my $tmp_smets_loc = "/tmp/$smets_name";

        eval {
            my %mdsecs = ();
            my $xpc = $volume->_parse_xpc($tmp_smets_loc);
            $xpc->registerNs('gbs',"http://books.google.com/gbs");
            foreach my $mdsec ( $xpc->findnodes('//mets:mdWrap') ) {
                my @mdbits = ();
                foreach my $attr (qw(LABEL MDTYPE OTHERMDTYPE)) {
                    my $attrval = $mdsec->getAttribute($attr);
                    if($attrval and $attrval ne '') {
                        push(@mdbits,"$attr=$attrval");
                    }
                }
                $mdsecs{join('; ',@mdbits)} = 1;
            }
            foreach my $mdsec ( sort(keys(%mdsecs)) ) {
                mets_ins($namespace,$objid,"SRC_METS_MDSEC",$mdsec);
            }

            # Try to get Google reading order
            foreach my $tag (qw(gbs:pageOrder gbs:pageSequence gbs:coverTag)) {
                my $val = $xpc->findvalue("//$tag");
                mets_ins($namespace,$objid,"GBS_READING",$tag,$val);
            }

        };
        if($@) {
            set_status($namespace,$objid,$srcmets[0],"BAD_SOURCE_METS",$@);
        }

        unlink($tmp_smets_loc);
         

    }
}

sub mets_ins {
    my $namespace = shift;
    my $objid = shift;
    my $key = shift;
    my $val1 = shift;
    my $val2 = shift;
    $val1 = '' if not defined $val1;
    $val2 = '' if not defined $val2;
    print join("\t",$namespace,$objid,$key,$val1,$val2), "\n";
    #execute_stmt($fs_mets_data,$namespace,$objid,$key,$val1,$val2);
}

get_dbh()->disconnect();
close(RUN);

__END__
