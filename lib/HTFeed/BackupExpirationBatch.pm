#!/usr/bin/perl
package HTFeed::BackupExpirationBatch;

use strict;
use warnings;

use Carp ();
use Data::Dumper;

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

use Log::Log4perl qw(get_logger);

use HTFeed::Storage::PrefixedVersions;
use HTFeed::Storage::ObjectStore;

my $update_sql = <<~'SQL';
  UPDATE feed_backups
  SET deleted=1
  WHERE namespace=?
    AND id=?
    AND version=?
    AND storage_name=?
SQL


sub new {
  my $class = shift;

  my $self = {
    storage_name => undef,
    dry_run_text => '',
    @_
  };

  unless ($self->{storage_name}) {
    Carp::croak "$class cannot be constructed without a storage name";
  }

  unless ($self->{job_file}) {
    Carp::croak "$class cannot be constructed without a path to a job file";
  }

  unless (-e $self->{job_file}) {
    Carp::croak "job file does not exist: $self->{job_file}";
  }

  # Test can init with `storage_config` because it is transient and must be known to workers.
  # Production just reads the config as normal
  if (!$self->{storage_config}) {
    my $config = get_config('storage_classes');
    my $storage_config = $config->{$self->{storage_name}};
    die("Can't find storage configuration for " . $self->{storage_name}) unless $storage_config;
    $self->{storage_config} = $storage_config;
  }
  $self->{dry_run_text} = ' (DRY RUN)' if $self->{dry_run};
  $self->{update_sth} = get_dbh()->prepare($update_sql);

  bless($self, $class);
  return $self;
}

sub run {
  my $self = shift;

  open(my $fh, '<:encoding(UTF-8)', $self->{job_file}) or die "could not open $$self->{job_file}: $!";
  my $storage_deletes = [];
  my $database_deletes = [];
  while (1) {
    my $line = <$fh>;
    if ($line) {
      chomp $line;
      my ($namespace, $id, $version) = split(/\t/, $line, 3);
      push @$storage_deletes, @{$self->storage_keys($namespace, $id, $version)};
      push @$database_deletes, [$namespace, $id, $version];
    }
    # Now process the (sub)batch if max size or if at EOF.
    # Maximum batch size is 1000 for glacier but buy some wiggle room by using 990,
    # so we don't go over and have the whole batch fail.
    if (!$line || scalar @$storage_deletes >= 990) {
      $self->mass_delete($storage_deletes);
      $self->mass_update($database_deletes);
      $storage_deletes = [];
      $database_deletes = [];
    }
    last unless $line;
  }
}

# Use storage class `mass_delete` method to delete an arrayref of keys/files.
sub mass_delete {
  my $self = shift;
  my $storage_deletes = shift;

  return if $self->{dry_run};

  unless ($self->{storage_config}->{class}->mass_delete(
    config => $self->{storage_config},
    keys => $storage_deletes
  )) {
    die sprintf("mass_delete: unable to delete %d volumes", scalar $storage_deletes);
  }
}

# Update database to reflect deletion of arrayref of [namespace, id, version]
sub mass_update {
  my $self = shift;
  my $database_deletes = shift;

  return if $self->{dry_run};

  foreach my $row (@$database_deletes) {
    my ($namespace, $id, $version) = @$row;
    get_logger->trace("setting deleted=1 for $namespace.$id version $version");
    $self->{update_sth}->execute($namespace, $id, $version, $self->{storage_name});
  }
}

# return arrayref of keys/filenames to delete, typically the mets and zip
sub storage_keys {
  my $self = shift;
  my $namespace = shift;
  my $id = shift;
  my $version = shift;

  my $volume = new HTFeed::Volume(
    namespace => $namespace,
    objid => $id,
    package_type => 'ht'
  );
  my $storage = $self->{storage_config}->{class}->new(
    volume => $volume,
    config => $self->{storage_config},
    name => $self->{storage_name}
  );
  unless (defined $storage) {
    die "Unable to get storage for $volume->{namespace}.$volume->{objid}";
  }
  $storage->{timestamp} = $version;
  $storage->{zip_suffix} = '.gpg';
  return $storage->object_keys;
}

1;

__END__
