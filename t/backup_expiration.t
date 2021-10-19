use Test::Spec;

use HTFeed::BackupExpiration;
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Storage::ObjectStore;
use HTFeed::Storage::PrefixedVersions;

use strict;

describe "HTFeed::BackupExpiration" => sub {
  spec_helper 'storage_helper.pl';
  spec_helper 's3_helper.pl';
  local our ($tmpdirs, $testlog, $bucket, $s3);
  
  my $old_storage_classes;

  before each => sub {
    $old_storage_classes = get_config('storage_classes');
    my $new_storage_classes = {
      'prefixedversions-test' =>
      {
        class => 'HTFeed::Storage::PrefixedVersions',
        obj_dir => $tmpdirs->{backup_obj_dir},
        encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
      },
      'objectstore-test' =>
      {
        class => 'HTFeed::Storage::ObjectStore',
        bucket => $s3->{bucket},
        awscli => $s3->{awscli},
        encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
      }
    };
    set_config($new_storage_classes,'storage_classes');
  };

  after each => sub {
    set_config($old_storage_classes,'storage_classes');
  };

  sub prepare_storage {
    my $storage_name = shift;
    my $version = shift;
    my $volume = stage_volume($tmpdirs, 'test', 'test');
    my $storage_config = get_config('storage_classes')->{$storage_name};
    my $storage = $storage_config->{class}->new(volume => $volume,
                                                config => $storage_config,
                                                name   => $storage_name);
    $storage->{timestamp} = $version;
    $storage->encrypt;
    $storage->stage;
    $storage->make_object_path;
    $storage->move;
    $storage->record_backup;
    $storage->cleanup;
    return $storage;
  }

  sub old_random_timestamp {
    my $sql = 'SELECT DATE_FORMAT(DATE_SUB(NOW(), INTERVAL (180 + (RAND() * 180)) DAY),"%Y%m%d%H%i%S")';
    my @res = get_dbh->selectrow_array($sql);
    return $res[0];
  }

  sub new_random_timestamp {
    my $sql = 'SELECT DATE_FORMAT(DATE_SUB(NOW(), INTERVAL (RAND() * 180) DAY),"%Y%m%d%H%i%S")';
    my @res = get_dbh->selectrow_array($sql);
    return $res[0];
  }

  sub zip_deleted {
    my $storage = shift;

    if ($storage->{name} eq 'prefixedversions-test') {
      return !-e $storage->zip_obj_path();
    } else {
      eval {
        my $result = $s3->s3api('head-object','--key',"test.test.$storage->{timestamp}.zip.gpg");
      };
      return defined $@ && $@ =~ m/404/;
    }
  }

  sub mets_deleted {
    my $storage = shift;

    if ($storage->{name} eq 'prefixedversions-test') {
      return !-e $storage->mets_obj_path();
    } else {
      eval {
        $s3->s3api('head-object','--key',"test.test.$storage->{timestamp}.mets.xml");
      };
      return defined $@ && $@ =~ m/404/;
    }
  }

  sub count_deleted_objects {
    my $namespace = shift;
    my $objid = shift;
    my $version = shift;

    my $sql = 'SELECT COUNT(*) FROM feed_backups' .
              ' WHERE namespace=? AND id=? AND deleted=1';
    my @bind = ($namespace, $objid);
    if (defined $version) {
      $sql .= ' AND version=?';
      push @bind, $version;
    }
    my @res = get_dbh->selectrow_array($sql, undef, @bind);
    return $res[0];
  }

  share my %vars;
  shared_examples_for "all storages" => sub {
    it "should create expiration object" => sub {
      my $exp = HTFeed::BackupExpiration->new(storage_name => $vars{storage_name});
      ok($exp, 'new returns a value');
      is($exp->{storage_name}, $vars{storage_name}, 'expiration has correct storage name');
    };

    it "does not do anything with a single old version" => sub {
      my $storage = prepare_storage($vars{storage_name}, old_random_timestamp());
      my $exp = HTFeed::BackupExpiration->new(storage_name => $vars{storage_name});
      $exp->run();
      my $deleted = count_deleted_objects('test', 'test', $storage->{timestamp});
      is($deleted, 0, 'object is not deleted');
      ok(!mets_deleted($storage), "single ($storage->{timestamp}) mets left intact");
      ok(!zip_deleted($storage), "single ($storage->{timestamp}) zip left intact");
    };

    it "does not do anything with a single old version and single new one" => sub {
      my $old_storage = prepare_storage($vars{storage_name}, old_random_timestamp());
      my $new_storage = prepare_storage($vars{storage_name}, new_random_timestamp());
      my $exp = HTFeed::BackupExpiration->new(storage_name => $vars{storage_name});
      $exp->run();
      my $deleted = count_deleted_objects('test', 'test', $old_storage->{timestamp});
      is($deleted, 0, 'old object is not deleted');
      ok(!mets_deleted($old_storage), "old ($old_storage->{timestamp}) mets left intact");
      ok(!zip_deleted($old_storage), "old ($old_storage->{timestamp}) zip left intact");

      $deleted = count_deleted_objects('test', 'test', $new_storage->{timestamp});
      is($deleted, 0, 'new object is not deleted');
      ok(!mets_deleted($new_storage), "new ($new_storage->{timestamp}) mets left intact");
      ok(!zip_deleted($new_storage), "new ($new_storage->{timestamp}) zip left intact");
    };

    it "does not delete old versions when there is nothing new" => sub {
      my @old_versions;
      foreach my $n (1 .. 2) {
        my $storage = prepare_storage($vars{storage_name}, old_random_timestamp());
        push @old_versions, $storage;
      }
      my $exp = HTFeed::BackupExpiration->new(storage_name => $vars{storage_name});
      $exp->run();
      foreach my $old_storage (@old_versions) {
        my $deleted = count_deleted_objects('test', 'test', $old_storage->{timestamp});
        is($deleted, 0, 'old object is not marked feed_backups.deleted');
        ok(!mets_deleted($old_storage), "old ($old_storage->{timestamp}) mets left intact");
        ok(!zip_deleted($old_storage), "old ($old_storage->{timestamp}) zip left intact");
      }
    };

    it "deletes the oldest old version when there is a new one" => sub {
      my @old_versions;
      foreach my $n (1 .. 2) {
        my $storage = prepare_storage($vars{storage_name}, old_random_timestamp());
        push @old_versions, $storage;
      }
      my ($older, $newer) = @old_versions;
      if ($old_versions[0]->{timestamp} > $old_versions[1]->{timestamp}) {
        ($newer, $older) = @old_versions;
      }
      my $storage = prepare_storage($vars{storage_name}, new_random_timestamp());
      my $exp = HTFeed::BackupExpiration->new(storage_name => $vars{storage_name});
      $exp->run();
      my $deleted = count_deleted_objects('test', 'test', $older->{timestamp});
      is($deleted, 1, 'older object is marked feed_backups.deleted');
      ok(mets_deleted($older), "older ($older->{timestamp}) mets deleted");
      ok(zip_deleted($older), "older ($older->{timestamp}) zip deleted");
      $deleted = count_deleted_objects('test', 'test', $newer->{timestamp});
      is($deleted, 0, 'newer object is not marked feed_backups.deleted');
      ok(!mets_deleted($newer), "newer ($newer->{timestamp}) mets left intact");
      ok(!zip_deleted($newer), "newer ($newer->{timestamp}) zip left intact");
      ok(!mets_deleted($storage), "new ($storage->{timestamp}) mets left intact");
      ok(!zip_deleted($storage), "new ($storage->{timestamp}) zip left intact");
    };

    it "keeps all new versions" => sub {
      my @new_versions;
      foreach my $n (1 .. 2) {
        my $storage = prepare_storage($vars{storage_name}, new_random_timestamp());
        push @new_versions, $storage;
      }
      my $exp = HTFeed::BackupExpiration->new(storage_name => $vars{storage_name});
      $exp->run();
      my $deleted = count_deleted_objects('test', 'test');
      is($deleted, 0, 'no objects are marked feed_backups.deleted');
      foreach my $new_storage (@new_versions) {
        ok(!mets_deleted($new_storage), "new ($new_storage->{timestamp}) mets left intact");
        ok(!zip_deleted($new_storage), "new ($new_storage->{timestamp}) zip left intact");
      }
    };
  };

  describe "HTFeed::BackupExpiration for PrefixedVersions" => sub {
    before each => sub {
      $vars{storage_name} = 'prefixedversions-test';
    };

    it_should_behave_like "all storages";
  };

  describe "HTFeed::BackupExpiration for ObjectStore" => sub {
    before each => sub {
      $vars{storage_name} = 'objectstore-test';
    };

    it_should_behave_like "all storages";
  };
};

runtests unless caller;
