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

# Iterates through feed_backups produces an error for each zip/xml not in AWS.
# If limit is defined, checks that number of volumes.
# Returns number of errors.
sub run_not_in_aws_check {
  my $self  = shift;
  my $limit = shift;

  my $err_count = 0;
  my $s3 = HTFeed::Storage::S3->new(bucket => $self->{bucket},
                                    awscli => $self->{awscli});
  my $sql = 'SELECT namespace,id,version FROM feed_backups'.
            ' WHERE path LIKE "s3://%"'.
            ' AND deleted IS NULL'.
            ' ORDER BY lastchecked ASC';
  $sql .= "LIMIT $limit" if defined $limit;
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
  }
  return $err_count;
}

# Iterates through S3 bucket and produces an error for each item not in feed_backups.
# If limit is defined, checks that number of objects.
# Returns number of errors.
# This subroutine double-reports since it checks both the METS and ZIP.
sub run_not_in_db_check {
  my $self  = shift;
  my $limit = shift;

  return 0 if defined $limit and $limit == 0;

  my $s3 = HTFeed::Storage::S3->new(bucket => $self->{bucket},
                                    awscli => $self->{awscli});
  my @next_token_params = ();
  my $count = 0;
  my $err_count = 0;
  while(1) {
    my $result = $s3->s3api("list-objects-v2",@next_token_params);
    last unless $result;

    foreach my $object (@{$result->{Contents}}) {
      my ($namespace, $id, $version, $_rest) = split m/\./, $object->{Key};
      my $sql = 'SELECT COUNT(*) FROM feed_backups WHERE namespace = ? AND id = ? AND version = ?';
      my $row = get_dbh()->selectrow_arrayref($sql, undef, $namespace, $id, $version);
      if ($row->[0] == 0) {
        $self->log_error($namespace, $id, 'MissingField', "AWS object $object->{Key} not found in feed_backups");
        $err_count++;
      }
      $count++;
      last if defined $limit && $count >= $limit;
    }
    last unless $result->{NextToken};
    last if defined $limit && $count >= $limit;

    @next_token_params = ('--starting-token',$result->{NextToken});
  }
  return $err_count;
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
