#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use DBI;
use File::Basename;
use File::Pairtree qw(ppath2id s2ppchars);
use FindBin;
use POSIX qw(strftime);
use Getopt::Long;
use URI::Escape;

use lib "$FindBin::Bin/../../lib";
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::METS;
use HTFeed::Namespace;
use HTFeed::PackageType;
use HTFeed::RepositoryIterator;
use HTFeed::Volume;
use HTFeed::VolumeValidator;


# FIXME: is this needed?
my $tombstone_check = "select is_tombstoned from feed_audit where namespace = ? and id = ?";

my $insert =
"insert into feed_storage (namespace, id, storage_name, zip_size, mets_size, lastchecked) values(?,?,?,?,?,CURRENT_TIMESTAMP) \
ON DUPLICATE KEY UPDATE zip_size=?, mets_size=?, lastchecked = CURRENT_TIMESTAMP";

my $update =
"update feed_storage set md5check_ok = ?, lastmd5check = CURRENT_TIMESTAMP where namespace = ? and id = ? and storage_name = ?";

my $insert_detail =
"insert into feed_audit_detail (namespace, id, storage_name, path, status, detail) values (?,?,?,?,?,?)";

my $checkpoint_sel = 
"select lastmd5check > ? from feed_storage where namespace = ? and id = ?";

### set /sdr1 to /sdrX for test & parallelization

my $do_md5  = 0;
my $checkpoint = undef;
my $noop = undef;
my $storage_name = undef;
GetOptions(
  'md5!'           => \$do_md5,
  'checkpoint=s'   => \$checkpoint,
  'noop'           => \$noop,
  'storage_name=s' => \$storage_name,
);

# $storage_name must be one of 's3-truenas-ictc', 's3-truenas-macc'
if (!defined $storage_name) {
  die '--storage_name is required';
}
if ($storage_name ne 's3-truenas-macc' && $storage_name ne 's3-truenas-ictc') {
  die "--storage_name must have value of 's3-truenas-macc' or 's3-truenas-ictc";
}

my $base = shift @ARGV or die("Missing base directory..");
my $iterator = HTFeed::RepositoryIterator->new($base);

while (my $obj = $iterator->next_object) {
  my $sdr_partition = $obj->{sdr_partition};
  my $path = $obj->{path};
  my $namespace = $obj->{namespace};
  my $objid = $obj->{objid};
  eval {
    if ($obj->{directory_objid} ne $objid) {
      set_status( $namespace, $objid, $storage_name, $path, "BAD_PAIRTREE",
        "$objid $obj->{directory_objid}" );
    }

    #get last modified date
    my $zipfile = "$obj->{path}/$obj->{objid}.zip";
    my $zip_seconds;
    my $zipdate;
    my $zipsize;

    if ( -e $zipfile ) {
      $zip_seconds = ( stat($zipfile) )[9];
      $zipdate = strftime( "%Y-%m-%d %H:%M:%S", localtime($zip_seconds) );
      $zipsize = -s $zipfile;
    }

    my $metsfile = "$obj->{path}/$obj->{objid}.mets.xml";

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

    # FIXME: I don't know if this is needed and if it is this is old code from main_repo_audit.pl so it needs fixin'
    #test symlinks unless we're traversing sdr1 or the file is too new
    # if ( $first_path ne 'sdr1' and (defined $last_touched and time - $last_touched >= 86400) ) {
#       my $link_path = join( "/", "/sdr1", @pathcomp, $last_path );
#       my $link_target = readlink $link_path
#         or set_status( $namespace, $objid, $path, "CANT_LSTAT",
#         "$link_path $!" );
# 
#       if ( defined $link_target and $link_target ne $path ) {
#         set_status( $namespace, $objid, $path, "SYMLINK_INVALID",
#           $link_target );
#       }
# 
#     }


    #insert
    execute_stmt(
      $insert,  
      $namespace, $objid, $storage_name,
      $zipsize, $metssize, 
      # duplicate parameters for duplicate key update
      $zipsize, $metssize, 
    );

    # does barcode have a zip & xml, and do they match?

    my $filecount  = 0;
    my $found_zip  = 0;
    my $found_mets = 0;
    foreach my $file (@{$obj->{contents}}) {
      next if $file =~ /pre_uplift.mets.xml$/;    # ignore backup mets
      if ( $file !~ /^([^.]+)\.(zip|mets.xml)$/ ) {
        set_status($namespace, $objid, $storage_name, $path, "BAD_FILE", "$file");
        next;
      }
      my $dir_barcode = $1;
      my $ext         = $2;
      $found_zip++  if $ext eq 'zip';
      $found_mets++ if $ext eq 'mets.xml';
      if ($objid ne $dir_barcode) {
        set_status($namespace, $objid, $storage_name, $path, "BARCODE_MISMATCH", "$objid $dir_barcode");
      }
      $filecount++;
    }

    # check file count; do md5 check and METS extraction stuff
    if (defined $zip_seconds || defined $mets_seconds) {
      if ( $filecount > 2 or $filecount < 1 or ($found_zip != 1 and not is_tombstoned($namespace,$objid) ) or $found_mets != 1 ) {
        set_status( $namespace, $objid, $storage_name, $path, "BAD_FILECOUNT",
          "zip=$found_zip mets=$found_mets total=$filecount" );
      }

      eval {
        my $rval = zipcheck( $namespace, $objid, $storage_name );
        if ($rval) {
          execute_stmt( $update, "1", $namespace, $objid, $storage_name );
        }
        elsif ( defined $rval ) {
          execute_stmt( $update, "0", $namespace, $objid, $storage_name );
        }
      };
      if ($@) {
        set_status( $namespace, $objid, $storage_name, $path, "CANT_ZIPCHECK", $@ );
      }
    }

  };

  if ($@) {
    warn($@);
  }
}

get_dbh()->disconnect();
$iterator->close;

sub zipcheck {
  my ( $namespace, $objid, $storage_name ) = @_;

  return unless $do_md5;

  return if is_tombstoned($namespace, $objid);

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
      set_status( $namespace, $objid, $storage_name,
        $volume->get_repository_mets_path(),
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
        set_status( $namespace, $objid, $storage_name,
          $volume->get_repository_zip_path(),
          "BAD_CHECKSUM", "expected=$mets_zipsum actual=$realsum" );
        $rval = 0;
      }
    }
  }
  return $rval;
}

sub set_status {
  warn( join( " ", @_ ), "\n" );
  execute_stmt( $insert_detail, @_ );
}

sub execute_stmt {
  my $stmt = shift;

  # Bail out if noop and the SQL statement is mutating, SELECT is okay
  return if $noop and ($stmt =~ /^insert|update/);

  my $dbh  = get_dbh();
  my $sth  = $dbh->prepare($stmt);
  $sth->execute(@_);
  return $sth;
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

sub recently_modified_path {
  my $path = shift;

  my $mtime = ( stat($path) )[9];
  my $mtime_age = time() - $mtime;

  return 1 if $mtime_age < (86400 * 2);
}

sub recent_previous_version {
  my $file = shift;

  return unless $file =~ /.old$/;

  my $ctime = ( stat($file) )[10];
  my $ctime_age = time() - $ctime;

  return 1 if $ctime_age < (86400 * 2);
  
}

__END__
