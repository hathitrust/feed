#!/usr/bin/perl
package HTFeed::BackupExpiration;

use strict;
use warnings;

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

use Carp ();
use File::Spec ();
use File::Temp ();
use Log::Log4perl qw(get_logger);
use YAML::XS ();

my $select_expired_sql = <<~'SQL';
  SELECT namespace,id
  FROM feed_backups
  WHERE deleted IS NULL
    AND storage_name=?
    AND version < DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 180 DAY),"%Y%m%d%H%i%S")
  GROUP BY namespace,id
  HAVING COUNT(*) > 1
SQL

my $select_versions_sql = <<~'SQL';
  SELECT version
  FROM feed_backups
  WHERE deleted IS NULL
    AND storage_name=?
    AND namespace=?
    AND id=?
    AND version < DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 180 DAY),"%Y%m%d%H%i%S")
  ORDER BY version DESC
SQL


sub new {
  my $class = shift;

  my $self = {
    storage_name => undef,
    custom_storage_config => 0,
    max_workers => 8,
    job_size => 10000,
    limit => undef,
    @_
  };

  unless ($self->{storage_name}) {
    Carp::croak "$class cannot be constructed without a storage name";
  }

  # Test can init with `storage_config` because it is transient and must be known to workers.
  # Production just reads the config as normal
  if ($self->{storage_config}) {
    $self->{custom_storage_config} = 1;
  } else {
    my $config = get_config('storage_classes');
    my $storage_config = $config->{$self->{storage_name}};
    die("Can't find storage configuration for " . $self->{storage_name}) unless $storage_config;
    $self->{storage_config} = $storage_config;
  }

  $self->{temp_directory} = File::Temp->newdir;
  $self->{workers} = {};

  bless($self, $class);
  return $self;
}

sub run {
  my $self = shift;

  # Write storage config to the temp directory for child processes to get at it.
  # Unnecessary for production, needed for testing because it is generated as part
  # of the test suite.
  if ($self->{custom_storage_config}) {
    $self->{storage_config_file} = File::Spec->catfile($self->{temp_directory}, 'storage_config.yml');
    my $yaml = YAML::XS::Dump($self->{storage_config});
    open(my $fh, '>', $self->{storage_config_file}) or die "Could not open storage config YAML $!";
    print $fh $yaml;
    close $fh;
  }

  my $sth = get_dbh()->prepare($self->select_expired_sql);
  my $versions_sth = get_dbh()->prepare($select_versions_sql);

  my $job = [];
  # Iterate over the entirety of feed_backups
  # Reaching the end and restarting the query must take place at a
  # higher level, perhaps with $self->run called repeatedly.
  $sth->execute($self->{storage_name});
  while (my $row = $sth->fetchrow_hashref) {
    $versions_sth->execute($self->{storage_name}, $row->{namespace}, $row->{id});
    my @versions = map { $_->[0]; } @{$versions_sth->fetchall_arrayref};
    shift @versions; # jettison the most recent
    foreach my $version (@versions) {
      push(@$job, [$row->{namespace}, $row->{id}, $version]);
      # Do we have enough to spawn a worker?
      if (scalar @$job >= $self->{job_size}) {
        $self->wait_for_available_worker;
        $self->spawn_worker($job);
        $job = [];
      }
    }
  }
  # Submit the leftovers if any
  if (scalar @$job > 0) {
    $self->wait_for_available_worker;
    $self->spawn_worker($job);
    $job = [];
  }
  # Set max workers to 0 so we wait for all of them to finish.
  $self->{max_workers} = 0;
  # Wait for all the workers to finish.
  while (scalar keys %{$self->{workers}} > 0) {
    $self->wait_for_available_worker;
  }
}

# waitpid on existing workers (if any) until one finishes up
# but only if we are at maximum capacity.
# Only waits for workers to finish if we already have the maximum number on the go,
# or if we are finished and have set the maximum to 0.
sub wait_for_available_worker {
  my $self = shift;

  if (scalar keys %{$self->{workers}} >= $self->{max_workers}) {
    my $pid = 0;
    do {
      # Wait for any worker. This blocks indefinitely but there's nothing else
      # for this process to do but wait.
      $pid = waitpid(-1, 0);
      if ($pid > 0) {
        my $job_file = $self->{workers}->{$pid};
        get_logger->trace("worker [$pid] exited with status $? - removing $job_file");
        unlink $job_file->filename;
        delete $self->{workers}->{$pid};
      }
    } while ($pid > 0);
  }
}

sub spawn_worker {
  my $self = shift;
  my $job = shift;

  my $job_file = File::Temp->new(
    DIR => $self->{temp_directory},
    SUFFIX => '.tsv',
    CLEANUP => 0
  );
  foreach my $version (@$job) {
    print $job_file join("\t", @$version) . "\n";
  }
  $job_file->close;
  my $pid = fork();
  if (!defined $pid) {
    die "Fork failed: $!";
  } elsif ($pid == 0) {
    # WORKER PROCESS
    my $worker_script = File::Spec->catfile($ENV{FEED_HOME}, 'bin', 'expire_versions.pl');
    my @cmd = ('perl', $worker_script, '-s', $self->{storage_name});
    if ($self->{custom_storage_config}) {
      push @cmd, '--config', $self->{storage_config_file};
    }
    if ($self->{dry_run}) {
      push @cmd, '--dry-run';
    }
    push @cmd, $job_file->filename;
    exec(@cmd) or die "worker [$$] exec failed to run: $!\n";
  } else {
    # PARENT PROCESS
    get_logger->trace("worker [$pid] started with $job_file (" . scalar(@$job) . " items)");
    $self->{workers}->{$pid} = $job_file;
  }
}

sub select_expired_sql {
  my $self = shift;

  my $limit_clause = (defined $self->{limit}) ? " LIMIT $self->{limit}" : '';
  return $select_expired_sql . $limit_clause;
}

1;

__END__
