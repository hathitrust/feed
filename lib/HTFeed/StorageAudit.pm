#!/usr/bin/perl
package HTFeed::StorageAudit;

use strict;
use warnings;
use Carp;
use File::Temp;
use FindBin;
use Log::Log4perl qw(get_logger);

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

use Data::Dumper;

sub new {
  my $class = shift;

  my $self = {
    @_
  };

  die("Missing required argument 'storage_name'")
    unless $self->{storage_name};

  my $storage_config = get_config('storage_classes')->{$self->{storage_name}};
  die "No configuration found for storage '$self->{storage_name}'" unless defined $storage_config;
  $self->{storage_config} = $storage_config;
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

# Default filesystem iterator. Returns storage objects with additional fields,
# namely 'files' which points to a hash with zip and mets xml filenames (not paths).
# fs_crawl.pl makes sure all files in a directory are listed with no interleaving,
# so we can deduplicate the return values down to one per object.
# For Data Den we need to use something like fs_crawl but for the regular repo
# we should not because we won't have multiple versions potentially jammed into
# a single directory. May want to introduce a #crawl_command method. find is certain
# to be faster than fs_crawl.pl, may as well use it when we can.
sub object_iterator {
  my $self = shift;

  my $base =  $self->{storage_config}->{'obj_dir'};
  my $cmd = "$ENV{FEED_HOME}/bin/fs_crawl.pl $base";
  get_logger->trace("object_iterator running '$cmd'");
  open my $find_fh, '-|', $cmd or die("Can't open pipe to find: $!");
  my $last_obj = undef;
  return sub {
    my $obj = undef;
    while (!defined $obj) {
      my $path = <$find_fh>;
      unless (defined $path) {
        $obj = $last_obj;
        $last_obj = undef;
        last;
      }
      chomp($path);
      # ignore temporary location
      next if $path =~ qr(obj/\.tmp);
      my $parsed = $self->parse_object_path($path);
      # Don't process the same namespace/id/version twice
      if (!defined $last_obj || $last_obj->{id} ne $parsed->{id}) {
        $obj = $last_obj if defined $last_obj;
        $last_obj = $self->storage_object($parsed->{namespace}, $parsed->{objid},
                                          $parsed->{version}, $path);
        $last_obj->{id} = $parsed->{id}; # Temporary for deduplication
      }
      $last_obj->{files}->{$parsed->{file}} = 1;
    }
    delete $obj->{id} if defined $obj;
    return $obj;
  };
}

# Implemented by subclasses that run fs_crawl.pl to translate paths into
# an intermediate structure that can, when necessary, be used to create a storage_object.
# Currently no default implementation.
# See PrefixedVersions.pm for an example of the data structure expected of subclasses.
# It is a lighter weight struct compared to storage_object so it makes sense to defer
# creation of the latter.
sub parse_object_path {
  my $self = shift;
  my $path = shift;

  die 'unimplemented for storage classes other than PrefixedVersions';
}

# Choose and if necessary request a random object for this storage class.
sub random_object {
  my $self = shift;

  my $obj;
  my $sql = 'SELECT namespace,id,version,path FROM feed_backups' .
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
  my $version   = shift;
  my $path      = shift;

  unless ($namespace && $objid && $version) {
    croak "invalid storage_object() args: namespace, objid, version required";
  }
  my $obj = {namespace => $namespace, objid => $objid, version => $version,
             path => $path, storage_name => $self->{storage_name}};
  $obj->{volume} = HTFeed::Volume->new(packagetype => 'pkgtype',
                                       namespace   => $namespace,
                                       objid       => $objid);
  $obj->{storage} = $self->{storage_config}->{class}->new(volume    => $obj->{volume},
                                                          config    => $self->{storage_config},
                                                          name      => $self->{storage_name},
                                                          timestamp => $version);
  if ($obj->{storage}->encrypted_by_default) {
    $obj->{storage}->set_encrypted(1);
  }
  $obj->{path} = $obj->{storage}->audit_path unless $obj->{path};
  $obj->{zip_path} = $self->storage_object_path($obj) . '/' . $obj->{storage}->zip_filename;
  $obj->{mets_path} = $self->storage_object_path($obj) . '/' . $obj->{storage}->mets_filename;
  return $obj;
}

sub storage_object_path {
  my $self = shift;
  my $obj  = shift;

  return $obj->{path};
}

sub run_fixity_check {
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
  my $sql = 'SELECT saved_md5sum FROM feed_backups' .
            ' WHERE namespace=? AND id=? AND version=? AND storage_name=?';
  my ($dbsum) = get_dbh()->selectrow_array($sql, undef, $obj->{namespace},
                                           $obj->{objid}, $obj->{version},
                                           $obj->{storage_name});
  if (!defined $dbsum) {
    die "No checksum in DB for $self->{namespace} $self->{objid} $self->{version}";
  }
  my $realsum = HTFeed::VolumeValidator::md5sum($obj->{zip_path});
  return 1 if $dbsum eq $realsum;

  $self->set_error($obj, 'BadChecksum', version => $obj->{version},
                   expected => $dbsum, actual => $realsum);
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

# Checks completeness of database against storage.
# Iterates through storage and produces an error for each item not in feed_backups.
# Returns number of errors.
# If running run_storage_completeness_check as well as this routine,
# it is recommended to call this one first to populate lastchecked
# and reduce duplication in run_storage_completeness_check.
sub run_database_completeness_check {
  my $self  = shift;

  my $now_sth = get_dbh()->prepare('SELECT NOW()');
  $now_sth->execute();
  my ($lastchecked) = $now_sth->fetchrow_array();
  $self->{lastchecked} = $lastchecked;
  my $count = 0;
  my $err_count = 0;
  my $iterator = $self->object_iterator;
  get_logger->info('start database completeness check');
  while (my $obj = $iterator->()) {
    $err_count += $self->check_files($obj);
    my $rows = $self->update_lastchecked($obj);
    if (!$rows) {
      $self->set_error($obj, 'MissingField', description => 'no feed_backups entry',
                       version => $obj->{version}, path => $obj->{path});
      $err_count++;
    }
    $count++;
    if ($count % 100000 == 0) {
      get_logger->info("database completeness check: $count ($err_count errors)");
    }
  }
  get_logger->info("finish database completeness check ($count items, $err_count errors)");
  return $err_count;
}

# Returns number of errors encountered checking zip and mets presence in storage.
sub check_files {
  my $self = shift;
  my $obj  = shift;

  my $files = $obj->{files};
  unless ($files) {
    $self->set_error($obj, 'MissingField', description => 'unable to determine component files',
                     version => $obj->{version}, path => $obj->{path});
    return 1;
  }
  my $error_count = 0;
  unless ($files->{$obj->{storage}->zip_filename}) {
    $self->set_error($obj, 'MissingFile',
                     version => $obj->{version},
                     file => $obj->{storage}->zip_filename);
    $error_count++;
  }
  unless ($files->{$obj->{storage}->mets_filename}) {
    $self->set_error($obj, 'MissingFile',
                     version => $obj->{version},
                     file => $obj->{storage}->mets_filename);
    $error_count++;
  }
  return $error_count;
}

# Checks completeness of storage against database.
# Iterates through feed_backups and produces an error for each zip/xml not in storage.
# Returns number of errors.
sub run_storage_completeness_check {
  my $self  = shift;

  my $count = 0;
  my $err_count = 0;
  get_logger->info('start storage completeness check');
  my $sql = 'SELECT namespace,id,version,path FROM feed_backups'.
            ' WHERE storage_name=? AND deleted IS NULL';
  my @bindvals = ($self->{storage_name});
  if ($self->{lastchecked}) {
    $sql .= " AND lastchecked < ?";
    push(@bindvals, $self->{lastchecked});
  }
  my $sth = get_dbh()->prepare($sql);
  $sth->execute(@bindvals);
  while (my $row = $sth->fetchrow_arrayref()) {
    my $obj = $self->storage_object(@$row);
    unless ($self->is_object_zip_in_storage($obj)) {
      $self->set_error($obj, 'MissingFile',
                       version => $obj->{version},
                       file => $obj->{storage}->zip_filename);
      $err_count++;
    }
    unless ($self->is_object_mets_in_storage($obj)) {
      $self->set_error($obj, 'MissingFile',
                       version => $obj->{version},
                       file => $obj->{storage}->mets_filename);
      $err_count++;
    }
    $self->update_lastchecked($obj);
    $count++;
    if ($count % 100000 == 0) {
      get_logger->info("storage completeness check: $count ($err_count errors)");
    }
  }
  get_logger->info("finish storage completeness check ($count items, $err_count errors)");
  return $err_count;
}


sub is_object_zip_in_storage {
  my $self = shift;
  my $obj  = shift;

  return (-f $obj->{zip_path});
}

sub is_object_mets_in_storage {
  my $self = shift;
  my $obj  = shift;

  return (-f $obj->{mets_path});
}

# Updates feed_backups.lastchecked to current timestamp.
# Returns number of roes affected.
sub update_lastchecked {
  my $self = shift;
  my $obj  = shift;

  my $sql = 'UPDATE feed_backups SET lastchecked = NOW()'.
            ' WHERE namespace=? AND id=? AND version=? AND storage_name=?';
  my $update_sth = get_dbh()->prepare($sql);
  $update_sth->execute($obj->{namespace}, $obj->{objid}, $obj->{version},
                       $obj->{storage}->{name});
  return $update_sth->rows();
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

# ==== UTILITY CLASS METHOD ====
# adapted from File::Pairtree::ppath2id
sub ppchars2s {
  my $id = shift;

  # Reverse the single-char to single-char mapping.
  # This might add formerly hex-encoded chars back in.
  $id =~ tr /=+,/\/:./;   # per spec, =+, become /:.
  # Reject if there are any ^'s not followed by two hex digits.
  #
  die "error: impossible hex-encoding in $id" if
    $id =~ /\^($|.$|[^0-9a-fA-F].|.[^0-9a-fA-F])/;
  # Now reverse the hex conversion.
  #
  $id =~ s{
    \^([0-9a-fA-F]{2})
  }{
    chr(hex("0x"."$1"))
  }xeg;
  return $id;
}

1;

__END__
