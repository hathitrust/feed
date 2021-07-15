#!/usr/bin/perl
package HTFeed::StorageZipAudit;

use strict;
use warnings;
use Carp;
use File::Temp;
use FindBin;
use Log::Log4perl qw(get_logger);

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

sub new {
  my $class = shift;

  my $self = {
    @_
  };

  die("Missing required argument 'storage_name'")
    unless $self->{storage_name};

  bless($self, $class);
  return $self;
}

# Class method
sub for_storage_name {
  my $class        = shift;
  my $storage_name = shift;

  my $storage_config = get_config('storage_classes')->{$storage_name};
  die "No configuration found for storage '$storage_name'" unless defined $storage_config;

  return $storage_config->{class}->zip_audit_class->new(storage_name => $storage_name);
}

# Choose and if necessary request a random object for this storage class.
sub random_object {
  my $self = shift;

  my $obj;
  my $sql = 'SELECT namespace,id,path,version,saved_md5sum FROM feed_backups' .
            ' WHERE storage_name=?' .
            ' AND deleted IS NULL' .
            ' AND saved_md5sum IS NOT NULL' .
            ' AND restore_request IS NULL' .
            ' ORDER BY RAND() LIMIT 1';
  eval {
    my $ref = get_dbh->selectall_arrayref($sql, undef, $self->{storage_name});
    if (scalar @$ref) {
      $obj = $self->storage_object(@{$ref->[0]});
    }
  };
  if ($@) {
    die "Database query failed: $@";
  }
  return $obj;
}


# Get the object(s) selected for audit by choose_random_object() or some other criteria.
# In the case of AWS Glacier, it is one or more objects selected in a previous run
# that have been restored in the intervening time.
# These are the objects on the filesystem ready for checksumming.
sub all_objects {
  my $self = shift;

  return [$self->random_object()];
}

sub storage_object {
  my $self      = shift;
  my $namespace = shift;
  my $objid     = shift;
  my $path      = shift;
  my $version   = shift;
  my $md5       = shift;
  
  unless ($namespace && $objid && $path && $version && $md5) {
    croak "invalid storage_object() args: namespace, objid, path, version, md5 required";
  }
  my $obj = {namespace => $namespace, objid => $objid, version => $version,
             path => $path, storage_name => $self->{storage_name},
             md5 => $md5};
  $obj->{volume} = HTFeed::Volume->new(packagetype => 'pkgtype', namespace => $namespace, objid => $objid);
  my $config = get_config('storage_classes');
  $obj->{storage_config} = $config->{$self->{storage_name}};
  $obj->{storage} = $obj->{storage_config}->{class}->new(volume    => $obj->{volume},
                                                         config    => $obj->{storage_config},
                                                         name      => $self->{storage_name},
                                                         timestamp => $version);
  if ($obj->{storage}->encrypted_by_default) {
    $obj->{storage}->set_encrypted(1);
  }
  $obj->{zip_path} = $self->storage_object_path($obj) . '/' . $obj->{storage}->zip_filename;
  $obj->{mets_path} = $self->storage_object_path($obj) . '/' . $obj->{storage}->mets_filename;
  return $obj;
}

sub storage_object_path {
  my $self = shift;
  my $obj  = shift;

  return $obj->{path};
}

sub run {
  my $self = shift;
  my $obj  = shift;

  my $error_count = 0;
  my $objects = (defined $obj) ? [$obj] : $self->all_objects();
  unless (0 < scalar @$objects) {
    get_logger->trace("no auditable files: returning");
    return $error_count;
  }
  foreach my $obj (@$objects) {
    get_logger->info("start zip audit of $obj->{namespace}.$obj->{objid}.$obj->{version}");
    eval {
      die "encrypted zip $obj->{zip_path} does not exist" unless -f $obj->{zip_path};
      my $db_ok = $self->check_zip_against_database($obj);
      $error_count++ unless $db_ok;
      my $mets_ok = $self->check_zip_against_mets($obj);
      $error_count++ unless $mets_ok;
      my $sql = 'UPDATE feed_backups SET md5check_ok=?,lastmd5check=CURRENT_TIMESTAMP,restore_request=NULL'.
                ' WHERE namespace=? AND id=? AND version=? AND storage_name=?';
      execute_stmt($sql, ($db_ok && $mets_ok)? '1' : '0', $obj->{namespace},
                   $obj->{objid}, $obj->{version}, $self->{storage_nanme});
    };
    if ($@) {
      $self->set_error($obj, 'CANT_ZIPCHECK', "$obj->{version} $self->{storage_name}: $@");
    }
  }
  return $error_count;
}

sub set_error {
  my $self  = shift;
  my $obj   = shift;
  my $error = shift;

  my $logger = get_logger(ref($self));
  $logger->error(
      $error,
      namespace => $obj->{namespace},
      objid     => $obj->{objid},
      @_
  );
  $self->record_error($obj, [$error, @_]);
}

sub execute_stmt {
  my $stmt = shift;

  my $sth = get_dbh()->prepare($stmt);
  $sth->execute(@_);
  return $sth;
}

# Returns 1 if the encrypted zip file matches value in DB
sub check_zip_against_database {
  my $self = shift;
  my $obj  = shift;

  get_logger->trace("check_zip_against_database: $obj->{zip_path}");
  my $realsum = HTFeed::VolumeValidator::md5sum($obj->{zip_path});
  return 1 if $obj->{md5} eq $realsum;

  $self->set_error($obj, 'BadChecksum',
                   version => $obj->{version},
                   expected => $obj->{md5},
                   actual => $realsum);
  return 0;                       
}

sub check_zip_against_mets {
  my $self = shift;
  my $obj  = shift;

  get_logger->trace("check_zip_against_mets: $obj->{zip_path} and $obj->{mets_path}");
  my $ok = $obj->{storage}->validate_zip($self->storage_object_path($obj));
  return 1 if $ok;

  $self->record_error($obj, $obj->{storage}->{errors}->[-1]);
  return 0;
}

# Record an error structure in the feed_audit_detail table.
sub record_error {
  my $self = shift;
  my $obj  = shift;
  my $err  = shift;

  my $status = shift @$err;
  my %details = @$err;
  my $detail = join "\t", map { "$_: $details{$_}"; } keys %details;
  my $sql = 'INSERT INTO feed_audit_detail (namespace, id, path, status, detail)'.
            ' VALUES (?,?,?,?,?)';
  execute_stmt($sql, $obj->{namespace}, $obj->{objid}, $obj->{path}, $status, $detail);
}

1;

__END__
