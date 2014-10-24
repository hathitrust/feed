#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use File::Basename;
use File::Pairtree qw(ppath2id s2ppchars);
use HTFeed::Volume;
use HTFeed::VolumeValidator;
use HTFeed::Namespace;
use HTFeed::PackageType;
use HTFeed::METS;
use POSIX qw(strftime);
use Getopt::Long;
use URI::Escape;

my $insert =
"insert into feed_audit (namespace, id, sdr_partition, zip_size, zip_date, mets_size, mets_date, lastchecked) values(?,?,?,?,?,?,?,CURRENT_TIMESTAMP) \
               ON DUPLICATE KEY UPDATE sdr_partition = ?, zip_size=?, zip_date =?,mets_size=?,mets_date=?,lastchecked = CURRENT_TIMESTAMP";
my $update =
"update feed_audit set md5check_ok = ?, lastmd5check = CURRENT_TIMESTAMP where namespace = ? and id = ?";

my $update_mets = 
"update feed_audit set page_count = ?, image_size = ? where namespace = ? and id = ?";

my $insert_detail =
"insert into feed_audit_detail (namespace, id, path, status, detail) values (?,?,?,?,?)";

my $checkpoint_sel = 
"select lastmd5check > ? from feed_audit where namespace = ? and id = ?";

### set /sdr1 to /sdrX for test & parallelization
my $filesProcessed = 0;
my $prevpath;
my $do_md5  = 0;
my $do_mets = 0;
my $checkpoint = undef;
GetOptions(
    'md5!'  => \$do_md5,
    'mets!' => \$do_mets,
    'checkpoint=s' => \$checkpoint,
);

my $base = shift @ARGV or die("Missing base directory..");

my ($sdr_partition) = ($base =~ qr#/?sdr(\d+)/?#);

open( RUN, "find $base -follow -type f|" )
  or die("Can't open pipe to find: $!");

while ( my $line = <RUN> ) {

    my @newList = ();    #initialize array
    next if $line =~ /\Qpre_uplift.mets.xml\E/;

    eval {
        $filesProcessed++;

        #        if($filesProcessed % 10000== 0) {
        #            print "$filesProcessed files processed\n";
        #        }
        chomp($line);

        # strip trailing / from path
        my ( $pt_objid, $path, $type ) =
          fileparse( $line, qr/\.mets\.xml/, qr/\.zip/ );
        $path =~ s/\/$//;    # remove trailing /
        return if ( $prevpath and $path eq $prevpath );
        $prevpath = $path;

        my @pathcomp = split( "/", $path );

        # remove base & any empty components
        @pathcomp = grep { $_ ne '' } @pathcomp;
        my $first_path = shift @pathcomp;
        my $last_path  = pop @pathcomp;
        my $namespace  = $pathcomp[1];

        my $objid = ppath2id( join( "/", @pathcomp ) );
        if ( $pt_objid ne s2ppchars($objid) ) {
            set_status( $namespace, $objid, $path, "BAD_PAIRTREE",
                "$objid $pt_objid" );
        }

        if ( $last_path ne $pt_objid ) {
            set_status( $namespace, $objid, $path, "BAD_PAIRTREE",
                "$last_path $pt_objid" );
        }

        #get last modified date
        my $zipfile = "$path/$pt_objid.zip";
        my $zip_seconds;
        my $zipdate;
        my $zipsize;

        if ( -e $zipfile ) {
            $zip_seconds = ( stat($zipfile) )[9];
            $zipdate = strftime( "%Y-%m-%d %H:%M:%S", localtime($zip_seconds) );
            $zipsize = -s $zipfile;
        }

        my $metsfile = "$path/$pt_objid.mets.xml";

        my $mets_seconds;
        my $metsdate;
        my $metssize;

        if ( -e $metsfile ) {
            $mets_seconds = ( stat($metsfile) )[9];
            $metssize     = -s $metsfile;
            $metsdate     = strftime( "%Y-%m-%d %H:%M:%S",
                localtime( ( stat($metsfile) )[9] ) );
        }
        
        my $last_touched = $zip_seconds;
        $last_touched = $mets_seconds if defined $mets_seconds and (not defined $zip_seconds or $mets_seconds > $zip_seconds);

        #test symlinks unless we're traversing sdr1 or the file is too new
        if ( $first_path ne 'sdr1' and (defined $last_touched and time - $last_touched >= 86400) ) {
            my $link_path = join( "/", "/sdr1", @pathcomp, $last_path );
            my $link_target = readlink $link_path
              or set_status( $namespace, $objid, $path, "CANT_LSTAT",
                "$link_path $!" );

            if ( defined $link_target and $link_target ne $path ) {
                set_status( $namespace, $objid, $path, "SYMLINK_INVALID",
                    $link_target );
            }

        }

        #insert
        execute_stmt(
            $insert,  
            
            $namespace, $objid, 
         
            $sdr_partition, $zipsize, $zipdate, $metssize,  $metsdate, 
            
            # duplicate parameters for duplicate key update
            $sdr_partition, $zipsize, $zipdate, $metssize,  $metsdate
        );

        # does barcode have a zip & xml, and do they match?
        opendir( my $dh, $path );

        my $filecount  = 0;
        my $found_zip  = 0;
        my $found_mets = 0;
        while ( my $file = readdir($dh) ) {
            next
              if $file eq '.'
                  or $file eq '..'
                  or $file =~ /pre_uplift.mets.xml$/;    # ignore backup mets
            if ( $file !~ /^([^.]+)\.(zip|mets.xml)$/ ) {
                print("BAD_FILE $path $file\n");
            }
            my $dir_barcode = $1;
            my $ext         = $2;
            $found_zip++  if $ext eq 'zip';
            $found_mets++ if $ext eq 'mets.xml';
            if ( $pt_objid ne $dir_barcode ) {
                set_status( $namespace, $objid, $path, "BARCODE_MISMATCH",
                    "$pt_objid $dir_barcode" );
            }
            $filecount++;
        }

        closedir($dh);

# check file count; do md5 check and METS extraction stuff, but only if it's fully replicated
        if (   ( defined $zip_seconds and time - $zip_seconds > 86400 )
            or ( defined $mets_seconds and time - $mets_seconds > 86400 ) )
        {

            if ( $filecount != 2 or $found_zip != 1 or $found_mets != 1 ) {
                set_status( $namespace, $objid, $path, "BAD_FILECOUNT",
                    "zip=$found_zip mets=$found_mets total=$filecount" );
            }

            eval {
                my $rval = zipcheck( $namespace, $objid );
                if ($rval) {
                    execute_stmt( $update, "1", $namespace, $objid );
                }
                elsif ( defined $rval ) {
                    execute_stmt( $update, "0", $namespace, $objid );
                }
            };
            if ($@) {
                set_status( $namespace, $objid, $path, "CANT_ZIPCHECK", $@ );
            }
        }

    };

    if ($@) {
        warn($@);
    }
}

sub zipcheck {
    my ( $namespace, $objid ) = @_;

    return unless $do_md5 or $do_mets;

    # don't check this item if we just looked at it
    if(defined $checkpoint) {
        my $sth = execute_stmt($checkpoint_sel,$checkpoint,$namespace,$objid);
        if(my @row = $sth->fetchrow_array()) {
            return if @row and $row[0];
        }
    }

    # use google as a 'default' namespace for now
    my $volume = new HTFeed::Volume(
        packagetype => "pkgtype",
        namespace   => $namespace,
        objid       => $objid
    );
    my $mets = $volume->get_repository_mets_xpc();
    my $rval = undef;

# Extract the checksum for the zip file that looks kind of like this:
#  <METS:fileGrp ID="FG1" USE="zip archive">
#     <METS:file ID="ZIP00000001" MIMETYPE="application/zip" SEQ="00000001" CREATED="2008-11-22T20:07:28" SIZE="30844759" CHECKSUM="42417b735ae73a3e16d1cca59c7fac08" CHECKSUMTYPE="MD5">
#       <METS:FLocat LOCTYPE="OTHER" OTHERLOCTYPE="SYSTEM" xlink:href="39015603581748.zip" />
#     </METS:file>
#  </METS:fileGrp>

    if ($do_md5) {
        my $zipname     = $volume->get_zip_filename();
        my $mets_zipsum = $mets->findvalue(
            "//mets:file[mets:FLocat/\@xlink:href='$zipname']/\@CHECKSUM");

        if(not defined $mets_zipsum or length($mets_zipsum) ne 32) {
            # zip name may be uri-escaped in some cases
            $zipname = uri_escape($zipname);
            $mets_zipsum = $mets->findvalue(
                "//mets:file[mets:FLocat/\@xlink:href='$zipname']/\@CHECKSUM");
        }

        if ( not defined $mets_zipsum or length($mets_zipsum) ne 32 ) {
            set_status( $namespace, $objid, $volume->get_repository_mets_path(),
                "MISSING_METS_CHECKSUM", undef );
        }
        else {
            my $realsum = HTFeed::VolumeValidator::md5sum(
                $volume->get_repository_zip_path() );
            if ( $mets_zipsum eq $realsum ) {
                print "$zipname OK\n";
                $rval = 1;
            }
            else {
                set_status( $namespace, $objid,
                    $volume->get_repository_zip_path(),
                    "BAD_CHECKSUM", "expected=$mets_zipsum actual=$realsum" );
                $rval = 0;
            }
        }
    }

    if ($do_mets) {

        # extract other stuff from repo METS
        {    # File types & count
            my %filetypes;
            foreach my $file (
                $mets->findnodes('//mets:file/mets:FLocat/@xlink:href') )
            {
                my ($extension) = ( $file->value =~ /\.(\w+)$/ );
                $filetypes{$extension}++;
            }
            while ( my ( $ext, $count ) = each(%filetypes) ) {
                mets_log( $namespace, $objid, "FILETYPE", $ext, $count );
            }
        }

        {    # PREMIS & premis ID version
            my $premisversion = "none";
            if ( $mets->findnodes('//mets:mdWrap[@MDTYPE="PREMIS"]') ) {
                $premisversion = "unknown";
            }
            if ( $mets->findnodes('//mets:mdWrap//premis:premis') ) {
                $premisversion = "premis2";
            }

            mets_log( $namespace, $objid, "PREMIS_VERSION", $premisversion );
        }

        {    # PREMIS event ID types

            my %event_id_types = ();
            foreach my $eventtype (
                $mets->findnodes(
'//premis:eventIdentifierType'
                )
              )
            {
                $event_id_types{ $mets->findvalue( '.', $eventtype ) }++;
            }
            foreach my $event_id_type ( keys(%event_id_types) ) {
                mets_log( $namespace, $objid, "PREMIS_EVENT_TYPE",
                    $event_id_type, $event_id_types{$event_id_type} );
            }
        }

        {    # PREMIS agent types
            my %agent_id_types = ();
            foreach my $agenttype (
                $mets->findnodes(
'//premis:linkingAgentIdentifierType'
                )
              )
            {
                $agent_id_types{ $mets->findvalue( '.', $agenttype ) }++;
            }
            foreach my $agent_id_type ( keys(%agent_id_types) ) {
                mets_log( $namespace, $objid, "PREMIS_AGENT_TYPE",
                    $agent_id_type, $agent_id_types{$agent_id_type} );
            }

        }

        {    # Capturing agent
            foreach my $event (
                $mets->findnodes(
'//premis:event[premis:eventType="capture"]'
                )
              )
            {
                my $executor = $mets->findvalue(
'./premis:linkingAgentIdentifier[premis:linkingAgentRole="Executor"]/premis:linkingAgentIdentifierValue',
                    $event
                );
                my $date = $mets->findvalue(
                    './premis:eventDateTime',
                    $event );
                mets_log( $namespace, $objid, "CAPTURE", $executor, $date );
            }
        }
        {    # Processing agent
            foreach my $event (
                $mets->findnodes(
'//premis:event[premis:eventType="message digest calculation"]'
                )
              )
            {
                my $executor = $mets->findvalue(
'./premis:linkingAgentIdentifier[premis:linkingAgentRole="Executor"]/premis:linkingAgentIdentifierValue',
                    $event
                );
                my $date = $mets->findvalue(
                    './premis:eventDateTime',
                    $event );
                mets_log( $namespace, $objid, "MD5SUM", $executor, $date );
            }
        }

        {    # Ingest date
            foreach my $event (
                $mets->findnodes(
'//premis:event[premis:eventType="ingestion"]'
                )
              )
            {
                my $date = $mets->findvalue(
                    './premis:eventDateTime',
                    $event );
                mets_log( $namespace, $objid, "INGEST", $date );
            }
        }

        {    # MARC present
            my $marc_present =
              $mets->findvalue('count(//marc:record | //record)');
            mets_log( $namespace, $objid, "MARC", $marc_present );
        }

        {    # METS valid
            my ( $mets_valid, $error ) =
              HTFeed::METS::validate_xml( { volume => $volume },
                $volume->get_repository_mets_path() );
            if ( !$mets_valid ) {
                $error =~ s/\n/ /mg;
            }

            mets_log( $namespace, $objid, "METS_VALID", $mets_valid, $error );
        }

        {
            eval {
                my %mdsecs = ();
                foreach
                  my $mdsec ( $mets->findnodes('//mets:mdWrap | //mets:mdRef') )
                {
                    my @mdbits = ();
                    push( @mdbits, $mdsec->nodeName );
                    foreach my $attr (qw(LABEL MDTYPE OTHERMDTYPE)) {
                        my $attrval = $mdsec->getAttribute($attr);
                        if ( $attrval and $attrval ne '' ) {
                            push( @mdbits, "$attr=$attrval" );
                        }
                    }
                    mets_log( $namespace, $objid, "METS_MDSEC",
                        join( "; ", @mdbits ) );
                }
            }
        }

        {    # Page tagging, image size
            my $has_pagetags = $mets->findvalue(
                'count(//mets:div[@TYPE="page"]/@LABEL[string() != ""])');
            mets_log( $namespace, $objid, "PAGETAGS", $has_pagetags );
            my $pages = $mets->findvalue('count(//mets:div[@TYPE="page"])');
            mets_log( $namespace, $objid, "PAGES", $pages );


            my $image_size = $mets->findvalue('sum(//mets:fileGrp[@USE="image"]/mets:file/@SIZE)');
            mets_log( $namespace, $objid, "IMAGE_SIZE", $image_size);

            execute_stmt($update_mets,$pages,$image_size,$namespace,$objid);


        }

        extract_source_mets($volume);
    }
    return $rval;
}

sub set_status {
    warn( join( " ", @_ ), "\n" );
    execute_stmt( $insert_detail, @_ );
}

sub execute_stmt {
    my $stmt = shift;
    my $dbh  = get_dbh();
    my $sth  = $dbh->prepare($stmt);
    $sth->execute(@_);
    return $sth;
}

sub extract_source_mets {
    my $volume    = shift;
    my $namespace = $volume->get_namespace();
    my $objid     = $volume->get_objid();
    my $zipfile   = $volume->get_repository_zip_path();
    my $pt_objid  = $volume->get_pt_objid();
    my @srcmets   = ();

    open( my $zipinfo, "unzip -l '$zipfile'|" );
    while (<$zipinfo>) {
        chomp;
        my @zipfields = split /\s+/;
        if (    $zipfields[4]
            and $zipfields[4] =~ /^\Q$pt_objid\E\/\w+_\Q$pt_objid\E.xml/i )
        {
            push( @srcmets, $zipfields[4] );
        }
    }
    if ( !@srcmets ) {
        set_status( $namespace, $objid, $zipfile, "NO_SOURCE_METS", undef );
    }
    elsif ( @srcmets != 1 ) {
        set_status( $namespace, $objid, $zipfile,
            "MULTIPLE_SOURCE_METS_CANDIDATES", undef );
    }
    else {

        # source METS found
        mets_log( $namespace, $objid, "SOURCE_METS", $srcmets[0] );
        system("cd /tmp; unzip -j '$zipfile' '$srcmets[0]'");
        my ($smets_name) = ( $srcmets[0] =~ /\/([^\/]+)$/ );
        my $tmp_smets_loc = "/tmp/$smets_name";

        eval {
            my %mdsecs = ();
            my $xpc    = $volume->_parse_xpc($tmp_smets_loc);
            $xpc->registerNs( 'gbs', "http://books.google.com/gbs" );
            foreach my $mdsec ( $xpc->findnodes('//mets:mdWrap') ) {
                my @mdbits = ();
                foreach my $attr (qw(LABEL MDTYPE OTHERMDTYPE)) {
                    my $attrval = $mdsec->getAttribute($attr);
                    if ( $attrval and $attrval ne '' ) {
                        push( @mdbits, "$attr=$attrval" );
                    }
                }
                $mdsecs{ join( '; ', @mdbits ) } = 1;
            }
            foreach my $mdsec ( sort( keys(%mdsecs) ) ) {
                mets_log( $namespace, $objid, "SRC_METS_MDSEC", $mdsec );
            }

            # Try to get Google reading order
            foreach my $tag (qw(gbs:pageOrder gbs:pageSequence gbs:coverTag)) {
                my $val = $xpc->findvalue("//$tag");
                mets_log( $namespace, $objid, "GBS_READING", $tag, $val );
            }

            foreach my $techmd ( $xpc->findnodes("//mets:techMD") ) {
                if ( $techmd->getAttribute("ID") =~ /^IMAGE_METHOD/ ) {
                    my $imagemethod_id = $techmd->getAttribute("ID");
                    my $method =
                      $xpc->findvalue( ".//gbs:imageMethod", $techmd );
                    my $count = $xpc->findvalue(
"count(//mets:file[contains(\@ADMID,\"$imagemethod_id\")])"
                    );
                    mets_log( $namespace, $objid, "IMAGE_METHOD", $method,
                        $count );
                }
            }

        };
        if ($@) {
            set_status( $namespace, $objid, $srcmets[0], "BAD_SOURCE_METS",
                $@ );
        }

        unlink($tmp_smets_loc);

    }
}

sub mets_log {
    my $namespace = shift;
    my $objid     = shift;
    my $key       = shift;
    my $val1      = shift;
    my $val2      = shift;
    $val1 = '' if not defined $val1;
    $val2 = '' if not defined $val2;
    print join( "\t", $namespace, $objid, $key, $val1, $val2 ), "\n";

    #execute_stmt($fs_mets_data,$namespace,$objid,$key,$val1,$val2);
}

get_dbh()->disconnect();
close(RUN);

__END__
