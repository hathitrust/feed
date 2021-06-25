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

  describe "HTFeed::BackupExpiration for PrefixedVersions" => sub {
    describe "#new" => sub {
      it "succeeds" => sub {
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'prefixedversions-test');
        ok($exp, 'new returns a value');
      };
    };

    describe "#run" => sub {
      it "does not do anything with a single version" => sub {
        my $storage = prepare_storage('prefixedversions-test', old_random_timestamp());
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'prefixedversions-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND version=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $storage->{timestamp});
        is($res[0], 0, 'object is not deleted');
        ok(!mets_deleted($storage), "new ($storage->{timestamp}) mets left intact");
        ok(!zip_deleted($storage), "new ($storage->{timestamp}) zip left intact");
      };

      it "deletes old versions when there is a new one" => sub {
        my @old_versions;
        foreach my $n (1 .. 2) {
          my $storage = prepare_storage('prefixedversions-test', old_random_timestamp());
          push @old_versions, $storage;
        }
        my $storage = prepare_storage('prefixedversions-test', new_random_timestamp());
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'prefixedversions-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 2, 'two old objects marked with feed_backups.deleted=1');
        foreach my $old_storage (@old_versions) {
          ok(mets_deleted($old_storage), "old ($old_storage->{timestamp}) mets deleted");
          ok(zip_deleted($old_storage), "old ($old_storage->{timestamp}) zip deleted");
        }
        ok(!mets_deleted($storage), "new ($storage->{timestamp}) mets left intact");
        ok(!zip_deleted($storage), "new ($storage->{timestamp}) zip left intact");
      };

      it "keeps the newest old version" => sub {
        my @old_versions;
        foreach my $n (1 .. 2) {
          my $storage = prepare_storage('prefixedversions-test', old_random_timestamp());
          push @old_versions, $storage;
        }
        my ($older, $newer) = @old_versions;
        if ($old_versions[0]->{timestamp} > $old_versions[1]->{timestamp}) {
          ($newer, $older) = @old_versions;
        }
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'prefixedversions-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND version=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $older->{timestamp});
        is($res[0], 1, 'older object is marked feed_backups.deleted');
        ok(mets_deleted($older), "older ($older->{timestamp}) mets deleted");
        ok(zip_deleted($older), "older ($older->{timestamp}) zip deleted");
        $sql = 'SELECT COUNT(*) FROM feed_backups' .
               ' WHERE namespace=? AND id=? AND version=? AND deleted=1';
        @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $newer->{timestamp});
        is($res[0], 0, 'newer object is not marked feed_backups.deleted');
        ok(!mets_deleted($newer), "newer ($newer->{timestamp}) mets left intact");
        ok(!zip_deleted($newer), "newer ($newer->{timestamp}) zip left intact");
      };

      it "keeps all new versions" => sub {
        my @new_versions;
        foreach my $n (1 .. 2) {
          my $storage = prepare_storage('prefixedversions-test', new_random_timestamp());
          push @new_versions, $storage;
        }
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'prefixedversions-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 0, 'no objects are marked feed_backups.deleted');
        foreach my $new_storage (@new_versions) {
          ok(!mets_deleted($new_storage), "new ($new_storage->{timestamp}) mets left intact");
          ok(!zip_deleted($new_storage), "new ($new_storage->{timestamp}) zip left intact");
        }
      };
    };
  };

  describe "HTFeed::BackupExpiration for ObjectStore" => sub {
    describe "#new" => sub {
      it "succeeds" => sub {
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'objectstore-test');
        ok($exp, 'new returns a value');
      };
    };

    describe "#run" => sub {
      it "does not do anything with a single version" => sub {
        my $storage = prepare_storage('objectstore-test', old_random_timestamp());
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'objectstore-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND version=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $storage->{timestamp});
        is($res[0], 0, 'object is not deleted');
        ok(!mets_deleted($storage), "new ($storage->{timestamp}) mets left intact");
        ok(!zip_deleted($storage), "new ($storage->{timestamp}) zip left intact");
      };

      it "deletes old versions when there is a new one" => sub {
        my @old_versions;
        foreach my $n (1 .. 2) {
          my $storage = prepare_storage('objectstore-test', old_random_timestamp());
          push @old_versions, $storage;
        }
        my $storage = prepare_storage('objectstore-test', new_random_timestamp());
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'objectstore-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 2, 'two old objects marked with feed_backups.deleted=1');
        foreach my $old_storage (@old_versions) {
          ok(mets_deleted($old_storage), "old ($old_storage->{timestamp}) mets deleted");
          ok(zip_deleted($old_storage), "old ($old_storage->{timestamp}) zip deleted");
        }
        ok(!mets_deleted($storage), "new ($storage->{timestamp}) mets left intact");
        ok(!zip_deleted($storage), "new ($storage->{timestamp}) zip left intact");
      };

      it "keeps the newest old version" => sub {
        my @old_versions;
        foreach my $n (1 .. 2) {
          my $storage = prepare_storage('objectstore-test', old_random_timestamp());
          push @old_versions, $storage;
        }
        my ($older, $newer) = @old_versions;
        if ($old_versions[0]->{timestamp} > $old_versions[1]->{timestamp}) {
          ($newer, $older) = @old_versions;
        }
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'objectstore-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND version=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $older->{timestamp});
        is($res[0], 1, 'older object is marked feed_backups.deleted');
        ok(mets_deleted($older), "older ($older->{timestamp}) zip deleted");
        ok(zip_deleted($older), "older ($older->{timestamp}) mets deleted");
        $sql = 'SELECT COUNT(*) FROM feed_backups' .
               ' WHERE namespace=? AND id=? AND version=? AND deleted=1';
        @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $newer->{timestamp});
        is($res[0], 0, 'newer object is not marked feed_backups.deleted');
        ok(!mets_deleted($newer), "newer ($newer->{timestamp}) mets left intact");
        ok(!zip_deleted($newer), "newer ($newer->{timestamp}) zip left intact");
      };

      it "keeps all new versions" => sub {
        my @new_versions;
        foreach my $n (1 .. 2) {
          my $storage = prepare_storage('objectstore-test', new_random_timestamp());
          push @new_versions, $storage;
        }
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'objectstore-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 0, 'no objects are marked feed_backups.deleted');
        foreach my $new_storage (@new_versions) {
          ok(!mets_deleted($new_storage), "new ($new_storage->{timestamp}) mets left intact");
          ok(!zip_deleted($new_storage), "new ($new_storage->{timestamp}) zip left intact");
        }
      };
    };
  };
};

runtests unless caller;
