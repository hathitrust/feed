#!/usr/bin/perl
package HTFeed::DataDenZipAudit;

use strict;
use warnings;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;
use Carp;
use Log::Log4perl;

# Procedural function for randomly choosing a volume to check.
#
# my $vol = HTFeed::DataDenZipAudit->choose();
# my $audit = HTFeed::DataDenZipAudit->new(namespace => $vol->{namespace},
#                                          objid => $vol->{objid},
#                                          path => $vol->{path},
#                                          version => $vol->{version});
# my $result = $audit->run();
sub choose {
  my $storage_name = shift;

  die "Storage name is required" unless $storage_name;
  my $dbh = HTFeed::DBTools->get_dbh();
  my ($namespace, $objid, $path, $version);
  my $sql = 'SELECT namespace,id,path,version FROM feed_backups' .
            ' WHERE storage_name=?' .
            ' AND deleted IS NULL' .
            ' AND saved_md5sum IS NOT NULL' .
            ' ORDER BY RAND() LIMIT 1';
  eval {
    ($namespace, $objid, $path, $version) = $dbh->selectrow_array($sql, undef, $storage_name);
  };
  if ($@) {
    die "Database query failed: $@";
  }
  return { namespace => $namespace, objid => $objid, path => $path,
           version => $version, storage_name => $storage_name };
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
  unless ($self->{namespace} && $self->{objid} &&
          $self->{version} && $self->{path} && $self->{storage_name}) {
    croak "invalid args: namespace, objid, version, path, storage_name required";
  }

  my $volume = HTFeed::Volume->new(
    packagetype => 'pkgtype',
    namespace   => $self->{namespace},
    objid       => $self->{objid}
  );
  $self->{volume} = $volume;

  my $config = get_config('storage_classes');
  my $storage_config = $config->{$self->{storage_name}};
  die "Can't get config for storage '$self->{storage_name}'" unless $storage_config;

  $self->{storage} = $storage_config->{class}->new(volume => $volume,
                                                   config => $storage_config,
                                                   name   => $self->{storage_name});
  $self->{storage}->{timestamp} = $self->{version};
  $self->{storage}->{zip_suffix} = '.gpg';
  $self->{mets_path} = $self->{path} . '/' . $self->{storage}->mets_filename;
  $self->{zip_path} = $self->{path} . '/' . $self->{storage}->zip_filename;

  bless( $self, $class );
  return $self;
}

my $insert_detail =
"insert into feed_audit_detail (namespace, id, path, status, detail) values (?,?,?,?,?)";

my $update =
"update feed_backups set md5check_ok = ?, lastmd5check = CURRENT_TIMESTAMP where namespace = ? and id = ? and version = ?";

my $select_checksum =
"select saved_md5sum from feed_backups where namespace = ? AND id = ? AND version = ?";

sub run {
  my $self = shift;

  my $zipfile = $self->{zip_path};
  my ($db_ok, $mets_ok) = (0, 0);
  eval {
    die "encrypted zip $zipfile does not exist" unless -f $zipfile;
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
  my $realsum = HTFeed::VolumeValidator::md5sum(
    $self->{zip_path} );
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
