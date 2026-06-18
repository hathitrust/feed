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
  while (my $line = <$fh>) {
    chomp $line;
    my ($namespace, $id, $version) = split(/\t/, $line, 3);
    $self->delete_version($namespace, $id, $version);
  }
}

sub delete_version {
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
  get_logger->trace("deleting archive for $volume->{namespace}.$volume->{objid} version $version" . $self->{dry_run_text});
  return if $self->{dry_run};

  unless ($storage->delete_objects) {
    die "Unable to delete $volume->{namespace}.$volume->{objid} version $version";
  }
  get_logger->trace("setting deleted=1 for $volume->{namespace}.$volume->{objid} version $version");
  $self->{update_sth}->execute($namespace, $id, $version, $self->{storage_name});
}

1;

__END__
