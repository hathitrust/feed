#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use DBI;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Log {root_logger => 'INFO, screen'};
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
use Date::Manip;

my $tombstone_check = "select is_tombstoned from feed_audit where namespace = ? and id = ?";

my $insert =
"insert into feed_audit (namespace, id, sdr_partition, zip_size, zip_date, mets_size, mets_date, lastchecked) values(?,?,?,?,?,?,?,CURRENT_TIMESTAMP) \
ON DUPLICATE KEY UPDATE sdr_partition = ?, zip_size=?, zip_date =?,mets_size=?,mets_date=?,lastchecked = CURRENT_TIMESTAMP";

my $update_mets = 
"update feed_audit set page_count = ?, image_size = ?, first_ingest_date = ? where namespace = ? and id = ?";

my $insert_detail =
"insert into feed_audit_detail (namespace, id, path, status, detail, storage_name) values (?,?,?,?,?,'main_repo_audit')";

my $checkpoint_sel = 
"select lastmd5check > ? from feed_audit where namespace = ? and id = ?";

my $filesProcessed;
my $prevpath;
my $do_mets;
my $do_src_mets;
my $checkpoint;

sub reset_options {
  $filesProcessed = 0;
  $prevpath = undef;
  $do_mets = 0;
  $do_src_mets = 0;
  $checkpoint = undef;
}

sub main {
  reset_options;

  GetOptions(
    'mets!' => \$do_mets,
    'src_mets!' => \$do_src_mets,
    'checkpoint=s' => \$checkpoint,
  );

  my $base = shift @ARGV or die("Missing base directory..");

  open( RUN, "find $base -follow -type f|" )
    or die("Can't open pipe to find: $!");

  while ( my $line = <RUN> ) {
    audit_path($line);
  }

  get_dbh()->disconnect();
  close(RUN);
}

sub audit_path {
  my $line = shift;
  chomp($line);

  my ($sdr_partition) = ($line =~ qr#/?sdr(\d+)/?#);
  my @newList = ();    #initialize array
  next if $line =~ /\Qpre_uplift.mets.xml\E/;
  # ignore temporary location
  next if $line =~ qr(obj/\.tmp);
  next if $line =~ qr(obj/\w+/pairtree_version.*);
  next if $line =~ qr(obj/\w+/pairtree_prefix.*);
  
  # ignore ".old" files if they're recent
  next if recent_previous_version($line);

  eval {
    $filesProcessed++;

    #        if($filesProcessed % 10000== 0) {
    #            print "$filesProcessed files processed\n";
    #        }


    # strip trailing / from path
    my ( $pt_objid, $path, $type ) =
    fileparse( $line, qr/\.mets\.xml/, qr/\.zip/ );
    $path =~ s/\/$//;    # remove trailing /
    return if ( $prevpath and $path eq $prevpath );


    $prevpath = $path;

    unless ( $path =~ qr(obj/(\w+)/pairtree_root/(.*)) ) {
      warn("Can't parse path: $path");
    }
    my $namespace = $1;
    my @pathcomp = split("/", $2);
    my $last_path = pop(@pathcomp);

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
        or recent_previous_version("$path/$file")
        or $file =~ /pre_uplift.mets.xml$/;    # ignore backup mets
      if ( $file !~ /^([^.]+)\.(zip|mets.xml)$/ ) {
        print("BAD_FILE $path $file\n");
        next;
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

    # check file count; do METS extraction stuff
    if (   ( defined $zip_seconds )
        or ( defined $mets_seconds ) )
    {

      if ( $filecount > 2 or $filecount < 1 or ($found_zip != 1 and not is_tombstoned($namespace,$objid) ) or $found_mets != 1 ) {
        set_status( $namespace, $objid, $path, "BAD_FILECOUNT",
          "zip=$found_zip mets=$found_mets total=$filecount" );
      }

      eval {
        my $rval = check_metses( $namespace, $objid, $zipfile, $metsfile );
      };
      if ($@) {
        set_status( $namespace, $objid, $path, "CANT_METS_CHECK", $@ );
      }
    }

  };

  if ($@) {
    warn($@);
  }
}

sub check_metses {
  my ( $namespace, $objid, $zipfile, $metsfile ) = @_;

  return if is_tombstoned($namespace, $objid);

  # don't check this item if we just looked at it
  if(defined $checkpoint) {
    my $sth = execute_stmt($checkpoint_sel,$checkpoint,$namespace,$objid);
    if(my @row = $sth->fetchrow_array()) {
      return if @row and $row[0];
    }
  }

  my $volume = new HTFeed::Volume(
    packagetype => "pkgtype",
    namespace   => $namespace,
    objid       => $objid
  );
  my $mets = $volume->_parse_xpc($metsfile);
  my $rval = undef;

  if ($do_mets) {
    check_mets($volume, $metsfile, $mets);
  }

  if($do_src_mets) { 
    extract_source_mets($volume, $zipfile);
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

sub check_mets {
  my $volume    = shift;
  my $metsfile = shift;
  my $mets = shift;
  my $namespace = $volume->get_namespace();
  my $objid     = $volume->get_objid();

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
      $metsfile );
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

    my $first_ingest = first_ingest_date($mets);
    mets_log( $namespace, $objid, "FIRST_INGEST", $first_ingest);

    execute_stmt($update_mets,$pages,$image_size,$first_ingest,$namespace,$objid);


  }

}

sub first_ingest_date {
  my $mets = shift;

  my @dates;
  foreach my $event ($mets->findnodes('//premis:event[premis:eventType="ingestion"]')) {
      my $date = $mets->findvalue('./premis:eventDateTime',$event);
      push @dates, $date;
  }
  @dates = sort @dates;

  my $first_date = $dates[0];
  my $dm_date = Date::Manip::Date->new($first_date);
  return $dm_date->printf("%Y-%m-%d");
}

sub extract_source_mets {
  my $volume    = shift;
  my $zipfile   = shift;
  my $namespace = $volume->get_namespace();
  my $objid     = $volume->get_objid();
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

      {    # source METS PREMIS events
        foreach my $event (
          $xpc->findnodes(
            '//premis:event'
          )
        )
        {
          my $eventtype = $xpc->findvalue(
            './premis:eventType',
            $event
          );
          my $date = $xpc->findvalue(
            './premis:eventDateTime',
            $event );
          mets_log( $namespace, $objid, "SRC_METS_PREMIS_EVENT", $eventtype, $date );
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

sub is_tombstoned {
  my $namespace = shift;
  my $objid = shift;
  my $sth = execute_stmt($tombstone_check,$namespace,$objid);
  if(my @row = $sth->fetchrow_array()) {
    return $row[0];
  } else {
    return 0;
  }
}

sub recent_previous_version {
  my $file = shift;

  return unless $file =~ /.old$/;

  my $ctime = ( stat($file) )[10];
  my $ctime_age = time() - $ctime;

  return 1 if $ctime_age < (86400 * 2);
  
}

main unless caller;

__END__
