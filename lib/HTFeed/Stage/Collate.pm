package HTFeed::Stage::Collate;

use warnings;
use strict;

use base qw(HTFeed::Stage);

use HTFeed::Config qw(get_config);
use HTFeed::Storage::LocalPairtree;
use HTFeed::Storage::PairtreeObjectStore;
use HTFeed::Storage::ObjectStore;
use HTFeed::Storage::PrefixedVersions;
use Log::Log4perl qw(get_logger);
use POSIX qw(strftime);
use HTFeed::DBTools qw(get_dbh);

=head1 NAME

HTFeed::Stage::Collate

=head1 SYNOPSIS

  Deposits object to configured storage back end and verifies that it was
  deposited correctly.

=cut

sub storages {
  my $self = shift;
  return HTFeed::Storage::for_volume($self->{volume});
}

sub run{
  my $self = shift;

  $self->{is_repeat} = 0;
  my @storages       = @_;
  @storages          = $self->storages unless @storages;

  $self->{completed_storages} = [];

  foreach my $storage (@storages) {
    my $storage_failed = 0;

    my $result = eval { $self->collate($storage) };
    if (! $@ and defined $result and $result) {
      # TODO log how long it took
      $self->log_info("finished collate to $storage->{name}");
    } else {
      # TODO test that we log an error if it raises an exception?
      $self->log_warn("OperationFailed",operation => "collate", detail => "collate to $storage->{name} failed; will roll back");
      $storage_failed = 1;
    }
    push(@{$self->{completed_storages}}, $storage);

    $storage->clean_staging();

    if($storage_failed or @{$storage->{errors}}) {
      return $self->rollback;
    }

    $self->log_repeat($storage);
  }

  
  return $self->finalize;
}

sub finalize {
  my $self = shift;

  $self->log_info("Finished collating to all storages, cleaning up");
  foreach my $storage (@{$self->{completed_storages}}) {
    get_logger->debug("cleaning up $storage");
    $storage->cleanup;
  }

  $self->record_audit() if !$self->{failed};
  $self->_set_done();
  $self->{job_metrics}->inc("ingest_collate_items_total");
  return $self->succeeded();
}

sub rollback {
  my $self = shift;

  foreach my $storage (@{$self->{completed_storages}}) {
    get_logger()->debug("Rolling back collate to $storage->{name}");
    $storage->rollback;
  }
  $self->set_error("OperationFailed",operation => "collate", detail => "collate failed; finished rollback");
  $self->_set_done();
  return $self->succeeded();
}

sub log_repeat {
  my $self    = shift;
  my $storage = shift;

  my $volume = $self->{volume};

  if (-e $volume->get_zip_path() && -e $volume->get_mets_path()) {
    $self->{is_repeat} = 1;
    # deprecated format
    $self->log_info('Collating volume that is already in repo');
  }

}

sub collate {
  my $self = shift;
  my $storage = shift;

  $self->log_info("Starting collate for $storage->{name}");

  $storage->validate_zip_completeness &&
  $storage->encrypt                   &&
  $storage->verify_crypt              &&
  $storage->stage                     &&
  $storage->prevalidate               &&
  $storage->make_object_path          &&
  $storage->move                      &&
  $storage->postvalidate              &&
  $storage->record_audit;
}

sub success_info {
  my $self = shift;

  return "repeat=" . $self->{is_repeat};
}

sub stage_info{
  return {
    success_state => 'collated',
    failure_state => 'punted'
  };
}

sub clean_always{
  my $self = shift;

  $self->{volume}->clean_mets();
  $self->{volume}->clean_zip();
}

sub clean_success {
  my $self = shift;

  $self->{volume}->clear_premis_events();
  $self->{volume}->clean_sip_success();
}


sub file_date {
    my $self = shift;
    my $file = shift;

    if (-e $file) {
        my $seconds = (stat($file))[9];
        return strftime("%Y-%m-%d %H:%M:%S", localtime($seconds));
    }
}

# updates the zip_date in the feed_audit table to the current timestamp for
# this zip in the repository
#
# first_ingest_date is set by default to CURRENT_TIMESTAMP on first insert
sub record_audit {
    my $self = shift;

    my $stmt =
    "insert into feed_audit (namespace, id, zip_size, zip_date, mets_size, mets_date) \
    values(?,?,?,?,?,?) \
    ON DUPLICATE KEY UPDATE zip_size=?, zip_date =?,mets_size=?,mets_date=?";

    my $volume = $self->{volume};

    my $repo_path = $volume->get_repository_path();
    my $zip_path = $volume->get_repository_zip_path;
    die("Zip missing (in $repo_path) after collate") unless $zip_path and -e $zip_path;

    my $mets_path = $volume->get_repository_mets_path;
    die("METS missing (in $repo_path) after collate") unless $mets_path and -e $mets_path;

    my $zipsize  = -s $zip_path;
    my $zipdate  = $self->file_date($zip_path);
    my $metssize = -s $mets_path;
    my $metsdate = $self->file_date($mets_path);
    my $sth      = get_dbh()->prepare($stmt);
    get_logger()->trace("feed_audit: $zip_path / $zipdate / $zipsize bytes");
    get_logger()->trace("feed_audit: $mets_path / $metsdate / $metssize bytes");
    my $res      = $sth->execute(
        $volume->{namespace}, $volume->{objid}, 
        $zipsize, $zipdate, $metssize,  $metsdate,
        # duplicate parameters for duplicate key update
        $zipsize, $zipdate, $metssize,  $metsdate
    );

    return $res;
}

1;
