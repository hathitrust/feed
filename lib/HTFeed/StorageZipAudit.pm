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
  my $class        = shift;
  my $storage_name = shift;

  if (defined $storage_name) {
    # Instantiate audit subclass based on storage class name.
    my $config = get_config('storage_classes');
    my $storage_config = $config->{$storage_name};
    die "unable to get config for $storage_name" unless $storage_config;

    my @components = split '::', $storage_config->{class};
    my $module_class = $class . '::'. $components[-1];
    my $module_path = $module_class . '.pm';
    $module_path =~ s/::/\//g;
    require $module_path;
    my $self = $module_class->new();
    $self->{storage_name} = $storage_name;
    return $self;
  }
  else {
    return bless({}, $class);
  }
}

# Choose and if necessary request a random object for this storage class.
sub random_object {
  my $self = shift;

  my ($namespace, $objid, $path, $version);
  my $sql = 'SELECT namespace,id,path,version FROM feed_backups' .
            ' WHERE storage_name=?' .
            ' AND deleted IS NULL' .
            ' AND saved_md5sum IS NOT NULL' .
            ' AND restore_request IS NULL' .
            ' ORDER BY RAND() LIMIT 1';
  eval {
    my $ref = get_dbh->selectall_arrayref($sql, undef, $self->{storage_name});
    ($namespace, $objid, $path, $version) = @{$ref->[0]} if scalar @$ref;
  };
  if ($@) {
    die "Database query failed: $@";
  }
  return unless $namespace && $objid && $path && $version;
  return $self->storage_object($namespace, $objid, $path, $version);
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
  
  unless ($namespace && $objid && $path && $version) {
    croak "invalid storage_object() args: namespace, objid, path, version required";
  }
  my $obj = {namespace => $namespace, objid => $objid, version => $version,
             path => $path, storage_name => $self->{storage_name}};
  $obj->{volume} = HTFeed::Volume->new(packagetype => 'pkgtype', namespace => $namespace, objid => $objid);
  my $config = get_config('storage_classes');
  $obj->{storage_config} = $config->{$self->{storage_name}};
  $obj->{storage} = $obj->{storage_config}->{class}->new(volume => $obj->{volume},
                                                         config => $obj->{storage_config},
                                                         name   => $self->{storage_name});
  $obj->{storage}->{zip_suffix} = '.gpg';
  $obj->{storage}->{timestamp} = $obj->{version};
  $obj->{zip_file} = $obj->{storage}->zip_filename();
  $obj->{mets_file} = $obj->{storage}->mets_filename();
  $obj->{zip_path} = $self->storage_object_path($obj) . '/' . $obj->{zip_file};
  $obj->{mets_path} = $self->storage_object_path($obj) . '/' . $obj->{mets_file};
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
    eval {
      die "encrypted zip $obj->{zip_path} does not exist" unless -f $obj->{zip_path};
      my $db_ok = $self->check_encrypted_zip_against_database($obj);
      $error_count++ unless $db_ok;
      my $mets_ok = $self->check_decrypted_zip_against_mets($obj);
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
  my $self = shift;
  my $obj = shift;
  my $status = shift;
  my $detail = shift || '';

  my $logger = get_logger(ref($self));
  $logger->error($status, $detail);
  my $sql = 'INSERT INTO feed_audit_detail (namespace, id, path, status, detail)'.
            ' VALUES (?,?,?,?,?)';
  execute_stmt($sql, $obj->{namespace}, $obj->{objid}, $obj->{path}, $status, $detail);
}

sub execute_stmt {
  my $stmt = shift;

  my $sth = get_dbh()->prepare($stmt);
  $sth->execute(@_);
  return $sth;
}

# Returns 1 if the encrypted zip file matches value in DB
sub check_encrypted_zip_against_database {
  my $self = shift;
  my $obj  = shift;

  get_logger->trace("check_encrypted_zip_against_database: $obj->{zip_path}");
  my $sql = "SELECT saved_md5sum FROM feed_backups WHERE namespace=? AND id=? AND version=? AND storage_name=?";
  my ($db_zipsum) = get_dbh()->selectrow_array($sql, undef, $obj->{namespace},
                                               $obj->{objid}, $obj->{version},
                                               $obj->{storage_name});
  if (!defined $db_zipsum) {
    die "No checksum in DB for $self->{namespace} $self->{objid} $self->{version}";
  }
  my $realsum = HTFeed::VolumeValidator::md5sum($obj->{zip_path});
  return 1 if $db_zipsum eq $realsum;

  $self->set_error($obj, 'BadChecksum', "$obj->{version} $obj->{storage_name}: expected=$db_zipsum actual=$realsum");
  return 0;                       
}

sub check_decrypted_zip_against_mets {
  my $self = shift;
  my $obj  = shift;

  get_logger->trace("check_decrypted_zip_against_mets: $obj->{zip_path} and $obj->{mets_path}");
  my $mets = $obj->{volume}->_parse_xpc($obj->{mets_path});
  my $realsum = $obj->{storage}->crypted_md5sum($obj->{zip_path},
                                                $obj->{storage}->{config}{encryption_key});
  my $ok = $obj->{storage}->validate_zip_checksum($obj->{mets_path},
                                                  "gpg --decrypt '$obj->{zip_path}'",
                                                  $realsum);
  unless ($ok) {
    my @err = @{$obj->{storage}->{errors}->[-1]};
    my $status = shift @err;
    my %detail = @err;
    my $err = join ',', map { "$_=>$detail{$_}"; } keys %detail;
    $self->set_error($obj, $status, $err);
  }
  return $ok ? 1 : 0;
}

1;

__END__
