package HTFeed::Collator::LocalPairtree;
use HTFeed::Storage::LocalPairtree;

use HTFeed::Collator;
use base qw(HTFeed::Collator);

use strict;
use Log::Log4perl qw(get_logger);
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);
use HTFeed::VolumeValidator;
use URI::Escape;
use POSIX qw(strftime);
use HTFeed::DBTools qw(get_dbh);

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  $self->{storage} = HTFeed::Storage::LocalPairtree->new($self->{config});

  return $self;
}


sub object_path {
  my $self = shift;

  $self->{object_path} ||= $self->SUPER::object_path('obj_dir');
}

sub stage_path {
  my $self = shift;

  $self->SUPER::stage_path('obj_dir');
}

sub existing_object_tmpdir {
  my $self = shift;

  my $objdir = $self->follow_existing_link;

  if($objdir =~ qr(^(.*)/$self->{namespace}/pairtree_root/.*)) {
    get_logger()->trace("Using existing object dir $objdir; staging to $1/.tmp");
    return $self->stage_path_from_base($1);
  } else {
    die("Can't determine storage root from existing storage $objdir");
  }

}

sub move {
  my $self = shift;

  $self->move_existing_aside if $self->existing_object;

  $self->SUPER::move;
}

sub rollback {
  my $self = shift;

  return unless $self->{can_roll_back};

  my $zipfile = $self->zip_obj_path;
  my $metsfile = $self->mets_obj_path;

  get_logger()->warn("Rolling back to previous version");

  $self->safe_system('mv','-f',"$metsfile.old",$metsfile) if -e "$metsfile.old";
  $self->safe_system('mv','-f',"$zipfile.old",$zipfile) if -e "$zipfile.old";

  $self->SUPER::rollback;
};

sub cleanup {
  my $self = shift;

  my $zipfile = $self->zip_obj_path;
  my $metsfile = $self->mets_obj_path;

  $self->safe_system('rm','-f',"$metsfile.old") if -e "$metsfile.old";
  $self->safe_system('rm','-f',"$zipfile.old") if -e "$zipfile.old";

  $self->SUPER::cleanup;
}

sub move_existing_aside {
  my $self = shift;

  my $zipfile = $self->zip_obj_path;
  my $metsfile = $self->mets_obj_path;

  if( $self->safe_system('mv',$metsfile,"$metsfile.old") &&
      $self->safe_system('mv',$zipfile,"$zipfile.old") ) {
    $self->{can_roll_back} = 1;
  } else {
    die("$self->{namespace}.$self->{id}: Can't move aside existing object. Repository is likely inconsistent; manual intervention required");
  }
}

sub existing_object {
  my $self = shift;

  return -f $self->zip_obj_path && -f $self->mets_obj_path;
}

sub set_is_repeat {
  my $self = shift;

  if($self->existing_object) {
    $self->{is_repeat} = 1;
  } else {
    $self->{is_repeat} = 0;
  }
}

sub make_object_path {
  my $self = shift;

  if (! -d $self->object_path) {
    $self->safe_make_path($self->object_path);
  }

  $self->set_is_repeat;


  return 1;
}

sub file_date {
  my $self = shift;
  my $file = shift;

  if ( -e $file ) {
    my $seconds = ( stat($file) )[9];
    return strftime( "%Y-%m-%d %H:%M:%S", localtime($seconds) );
  }
}

# updates the zip_date in the feed_audit table to the current timestamp for
# this zip in the repository
sub record_audit {
  my $self = shift;

  my $path = $self->object_path();
  my ($sdr_partition) = ($path =~ qr#/?sdr(\d+)/?#);

  my $stmt =
  "insert into feed_audit (namespace, id, sdr_partition, zip_size, zip_date, mets_size, mets_date, lastchecked, lastmd5check, md5check_ok) values(?,?,?,?,?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,1) \
  ON DUPLICATE KEY UPDATE sdr_partition = ?, zip_size=?, zip_date =?,mets_size=?,mets_date=?,lastchecked = CURRENT_TIMESTAMP,lastmd5check = CURRENT_TIMESTAMP, md5check_ok = 1";

  # TODO populate image_size, page_count

  my $zipsize = $self->zip_size;
  my $zipdate = $self->file_date($self->zip_obj_path);

  my $metssize = $self->mets_size;
  my $metsdate = $self->file_date($self->mets_obj_path);

  my $sth  = get_dbh()->prepare($stmt);

  $sth->execute(
    $self->{namespace}, $self->{objid},

    $sdr_partition, $zipsize, $zipdate, $metssize,  $metsdate,

    # duplicate parameters for duplicate key update
    $sdr_partition, $zipsize, $zipdate, $metssize,  $metsdate
  );

}

1;
