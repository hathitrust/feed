package HTFeed::StorageAudit;

use warnings;
use strict;
use Carp;
use HTFeed::DBTools qw(get_dbh);
use Log::Log4perl qw(get_logger);

sub new {
  my $class = shift;

  my $object = {
      @_,
  };
  if ( $class ne __PACKAGE__ ) {
      croak "use __PACKAGE__ constructor to create $class object";
  }
  # check parameters
  croak "invalid args" unless ($object->{bucket} and $object->{awscli});
  bless( $object, $class );
  return $object;
}

# Queries for items in AWS but not the DB.
# Then queries for items in the DB but not AWS.
# These can be run independently, but by running run_not_in_aws_check second,
# the feed_backups.lastchecked timestamp produces fewer AWS s3_has queries
# and should speed up the operation.
sub run
{
  my $self = shift;

  my $err_count = $self->run_not_in_db_check();
  $err_count += $self->run_not_in_aws_check();
  return $err_count;
}


# Iterates through feed_backups produces an error for each zip/xml not in AWS.
# If limit is defined, checks that number of volumes.
# Returns number of errors.
sub run_not_in_aws_check {
  my $self  = shift;

  my $err_count = 0;
  my $s3 = HTFeed::Storage::S3->new(bucket => $self->{bucket},
                                    awscli => $self->{awscli});
  my $sql = 'SELECT namespace,id,version FROM feed_backups'.
            ' WHERE path LIKE "s3://%"'.
            ' AND deleted IS NULL';
  if ($self->{lastchecked}) {
    $sql .= " AND lastchecked < '$self->{lastchecked}'";
  }
  foreach my $row (@{get_dbh()->selectall_arrayref($sql)}) {
    my ($namespace, $id, $version) = @$row;
    unless ($s3->s3_has("$namespace.$id.$version.zip")) {
      $self->log_error($namespace, $id, 'MissingFile', "$namespace.$id.$version.zip not found in AWS");
      $err_count++;
    }
    unless ($s3->s3_has("$namespace.$id.$version.mets.xml")) {
      $self->log_error($namespace, $id, 'MissingFile', "$namespace.$id.$version.mets.xml not found in AWS");
      $err_count++;
    }
    $self->update_lastchecked($namespace, $id, $version);
  }
  return $err_count;
}

# Iterates through S3 bucket and produces an error for each item not in feed_backups.
# If limit is defined, checks that number of objects.
# Returns number of errors.
# This subroutine double-reports since it checks both the METS and ZIP.
sub run_not_in_db_check {
  my $self  = shift;

  my $err_count = 0;
  my $s3 = HTFeed::Storage::S3->new(bucket => $self->{bucket},
                                    awscli => $self->{awscli});
  my @next_token_params = ();
  my $now_sth = get_dbh()->prepare('SELECT NOW()');
  $now_sth->execute();
  my ($lastchecked) = $now_sth->fetchrow_array();
  $self->{lastchecked} = $lastchecked;

  while(1) {
    my $result = $s3->s3api('list-objects-v2', '--max-items' ,1000, @next_token_params);
    last unless $result;

    foreach my $object (@{$result->{Contents}}) {
      my ($namespace, $id, $version, $_rest) = split m/\./, $object->{Key};
     my $rows = $self->update_lastchecked($namespace, $id, $version);
      if (!$rows) {
        $self->log_error($namespace, $id, 'MissingField', "AWS object $object->{Key} not found in feed_backups");
        $err_count++;
      }
    }
    last unless $result->{NextToken};

    @next_token_params = ('--starting-token', $result->{NextToken});
  }
  return $err_count;
}

# Updates feed.backups.lastchecked and returns the number of rows affected.
sub update_lastchecked {
  my $self      = shift;
  my $namespace = shift;
  my $id        = shift;
  my $version   = shift;

  my $sql = 'UPDATE feed_backups SET lastchecked = NOW()'.
            ' WHERE namespace = ? AND id = ? AND version = ?';
  my $update_sth = get_dbh()->prepare($sql);
  $update_sth->execute($namespace, $id, $version);
  # https://stackoverflow.com/a/25685421
  return $update_sth->rows();
}

sub log_error {
  my $self      = shift;
  my $namespace = shift;
  my $id        = shift;
  my $errcode   = shift;
  my $detail    = shift;

  my $logger = get_logger( ref($self) );
  $logger->error($errcode, detail => $detail);
  my $sql = 'INSERT INTO feed_audit_detail (namespace, id, status, detail)'.
            ' values (?,?,?,?)';
  get_dbh()->prepare($sql)->execute($namespace, $id, $errcode, $detail);
}

1;
