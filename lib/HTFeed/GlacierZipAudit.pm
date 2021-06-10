#!/usr/bin/perl
package HTFeed::GlacierZipAudit;

use strict;
use warnings;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;
use Carp;
use Log::Log4perl;
use File::Temp;

# Procedural function for randomly choosing a volume to check.
#
# my $vol = HTFeed::GlacierZipAudit->choose('some-storage-name');
# my $audit = HTFeed::GlacierZipAudit->new(namespace => $vol->{namespace},
#                                          objid => $vol->{objid},
#                                          path => $vol->{path},
#                                          version => $vol->{version});
# $audit->submit_restore_object();
#
# later ...
# 
# my $volumes = HTFeed::GlacierZipAudit->pending_objects('some-storage-name');
# foreach my $vol (@$volumes) {
#   my $audit = HTFeed::GlacierZipAudit->new(namespace => $vol->{namespace},
#                                            objid => $vol->{objid},
#                                            path => $vol->{path},
#                                            version => $vol->{version});
#  my $result = $audit->run();
# }

sub choose {
  my $storage_name = shift;

  die "Storage name is required" unless $storage_name;
  my $dbh = HTFeed::DBTools->get_dbh();
  my ($namespace, $objid, $path, $version);
  my $sql = 'SELECT namespace,id,path,version FROM feed_backups' .
            ' WHERE storage_name=?' .
            ' AND deleted IS NULL' .
            ' AND saved_md5sum IS NOT NULL' .
            ' AND restore_request IS NULL' .
            ' ORDER BY RAND() LIMIT 1';
  eval {
    ($namespace, $objid, $path, $version) = $dbh->selectrow_array($sql, undef, $storage_name);
  };
  if ($@) {
    die "Database query failed: $@";
  }
  return { namespace => $namespace, objid => $objid,
           path => $path, version => $version, storage_name => $storage_name };
}

# Get the objects for which we have issued restore requests
sub pending_objects {
  my $storage_name = shift;

  die "Storage name is required" unless $storage_name;
  my $dbh = HTFeed::DBTools->get_dbh();
  my $sql = 'SELECT namespace,id,path,version FROM feed_backups' .
            ' WHERE storage_name=?' .
            ' AND restore_request IS NOT NULL';
  my $pending = [];
  eval {
    my $ref = $dbh->selectall_arrayref($sql, undef, $storage_name);
    foreach my $row (@$ref) {
      my ($namespace, $objid, $path, $version) = @$row;
      push @$pending, { namespace => $namespace, objid => $objid,
           path => $path, version => $version, storage_name => $storage_name };
    }
  };
  if ($@) {
    die "Database query failed: $@";
  }
  return $pending;
}

sub new {
  my $class = shift;

  my $self = {
      @_,
  };

  if ( $class ne __PACKAGE__ ) {
      croak "use __PACKAGE__ constructor to create $class object";
  }
  # check parameters
  unless ($self->{namespace} && $self->{objid} && $self->{version} && 
          $self->{storage_name}) {
    croak "invalid args: namespace, objid, version, storage_name required";
  }

  my $volume = HTFeed::Volume->new(
    packagetype => 'pkgtype',
    namespace   => $self->{namespace},
    objid       => $self->{objid}
  );
  $self->{volume} = $volume;

  my $config = get_config('storage_classes');
  my $storage_config = $config->{$self->{storage_name}};
  $self->{storage} = $storage_config->{class}->new(volume => $volume,
                                                   config => $storage_config,
                                                   name   => $self->{storage_name});
  $self->{tmpdir} = File::Temp::tempdir();
  $self->{zip_file} = join '.', ($self->{namespace}, $self->{objid}, $self->{version}, 'zip', 'gpg');
  $self->{mets_file} = join '.', ($self->{namespace}, $self->{objid}, $self->{version}, 'mets', 'xml');
  $self->{zip_path} = "$self->{tmpdir}/$self->{zip_file}";
  $self->{mets_path} = "$self->{tmpdir}/$self->{mets_file}";
  
  bless( $self, $class );
  return $self;
}

my $insert_detail =
"insert into feed_audit_detail (namespace, id, path, status, detail) values (?,?,?,?,?)";

my $update =
"update feed_backups set md5check_ok = ?, lastmd5check = CURRENT_TIMESTAMP, restore_request = NULL where namespace = ? and id = ? and version = ?";

my $select_checksum =
"select saved_md5sum from feed_backups where namespace = ? AND id = ? AND version = ?";

sub submit_restore_object {
  my $self = shift;

  my $req_json = '{"Days":10,"GlacierJobParameters":{"Tier":"Bulk"}}';
  $self->{storage}->{s3}->restore_object($self->{zip_file}, '--restore-request', $req_json);
  $self->{storage}->{s3}->restore_object($self->{mets_file}, '--restore-request', $req_json);
  my $sql = 'UPDATE feed_backups SET restore_request=CURRENT_TIMESTAMP' .
            ' WHERE namespace = ? AND id = ? AND version = ?';
  eval {
    HTFeed::DBTools->get_dbh()->prepare($sql)->execute($self->{namespace}, $self->{objid}, $self->{version});
  };
  if ($@) {
    die "Database operation failed: $@";
  }
  return 1;
}

sub get_files {
  my $self = shift;

  return if $self->{get_files_complete};
  $self->{storage}->{s3}->get_object($self->{storage}->{s3}->{'bucket'},
                                     $self->{zip_file}, $self->{zip_path});
  $self->{storage}->{s3}->get_object($self->{storage}->{s3}->{'bucket'},
                                     $self->{mets_file}, $self->{mets_path});
  $self->{get_files_complete} = 1;
}

# Returns 1 if both the zip and METS are ready for download.
sub check_files {
  my $self = shift;

  $self->{check_files_complete} = 1;

  my $result = $self->{storage}->{s3}->head_object($self->{zip_file});
  if ($result->{Restore} && $result->{Restore} =~ m/ongoing-request\s*=\s*"false"/) {
    $result = $self->{storage}->{s3}->head_object($self->{mets_file});
    if ($result->{Restore} && $result->{Restore} =~ m/ongoing-request\s*=\s*"false"/) {
      return 1;
    }
  }
  return 0;
}

sub run {
  my $self = shift;

  return unless $self->check_files() == 1;
  $self->get_files();
  my ($db_ok, $mets_ok) = (0, 0);
  eval {
    die "encrypted zip $self->{zip_path} does not exist" unless -f $self->{zip_path};
    $db_ok = $self->check_encrypted_zip_against_database();
    $mets_ok = $self->check_decrypted_zip_against_mets();
    if ($db_ok && $mets_ok) {
      execute_stmt($update, "1", $self->{namespace}, $self->{objid}, $self->{version});
    }
    else {
      execute_stmt($update, "0", $self->{namespace}, $self->{objid}, $self->{version});
    }
  };
  if ($@) {
    $self->set_error($self->{namespace}, $self->{objid}, 'CANT_ZIPCHECK', $@);
  }
  return ($db_ok && $mets_ok);
}

sub set_error {
  my $self = shift;
  my $namespace = shift;
  my $objid = shift;
  my $status = shift;
  my $detail = shift || '';
  # log error w/ l4p
  my $logger = Log::Log4perl::get_logger( ref($self) );
  $logger->error($status, $detail);
  execute_stmt($insert_detail, $namespace, $objid, $self->{path},
               $status, $detail);
}

sub execute_stmt {
  my $stmt = shift;
  my $dbh  = get_dbh();
  my $sth  = $dbh->prepare($stmt);
  $sth->execute(@_);
  return $sth;
}

# Returns 1 if the encrypted zip file matches value in DB
sub check_encrypted_zip_against_database {
  my $self = shift;

  my ($db_zipsum) = get_dbh()->selectrow_array($select_checksum, undef,
                                               $self->{namespace},
                                               $self->{objid},
                                               $self->{version});
  if (!defined $db_zipsum) {
    die "No checksum in DB for $self->{namespace} $self->{objid} $self->{version}";
  }
  my $realsum = HTFeed::VolumeValidator::md5sum($self->{zip_path});
  return 1 if $db_zipsum eq $realsum;

  $self->set_error($self->{namespace}, $self->{objid}, 'BadChecksum',
                   "expected=$db_zipsum actual=$realsum");
  return 0;                       
}

sub check_decrypted_zip_against_mets {
  my $self = shift;

  my $mets = $self->{volume}->_parse_xpc($self->{mets_path});
  my $storage = $self->{storage};
  my $realsum = $storage->crypted_md5sum($self->{zip_path},
                                         $storage->{config}{encryption_key});
  my $ok = $storage->validate_zip_checksum($self->{mets_path},
                                           "gpg --decrypt '$self->{zip_path}'",
                                           $realsum);
  unless ($ok) {
    my @err = @{$storage->{errors}->[-1]};
    my $status = shift @err;
    my %detail = @err;
    my $err = join ',', map { "$_=>$detail{$_}"; } keys %detail;
    $self->set_error($self->{namespace}, $self->{objid}, $status, $err);
  }
  return $ok ? 1 : 0;
}

1;

__END__
