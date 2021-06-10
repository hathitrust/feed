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

  sub staged_volume_storage {
    my $storage_name = shift;

    my $volume = stage_volume($tmpdirs, @_);
    my $storage_config = get_config('storage_classes')->{$storage_name};
    my $storage = $storage_config->{class}->new(volume => $volume,
                                                config => $storage_config,
                                                name   => $storage_name);
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

  describe "HTFeed::BackupExpiration for PrefixedVersions" => sub {
    describe "#new" => sub {
      it "succeeds" => sub {
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'prefixedversions-test');
        ok($exp, 'new returns a value');
      };
    };

    describe "#run" => sub {
      it "does not do anything with a single version" => sub {
        my $storage = staged_volume_storage('prefixedversions-test', 'test','test');
        my $version = old_random_timestamp();
        $storage->{timestamp} = $version;
        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->record_backup;
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'prefixedversions-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND version=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $version );
        is($res[0], 0, 'object is not deleted');
        my $mets = $storage->mets_obj_path();
        my $zip = $storage->zip_obj_path();
        ok(-e $mets, "new ($version) mets left intact");
        ok(-e $zip, "new ($version) zip left intact");
      };

      it "deletes old versions when there is a new one" => sub {
        my @old_versions;
        foreach my $n (1 .. 2) {
          my $storage = staged_volume_storage('prefixedversions-test', 'test','test');
          push @old_versions, $storage;
          my $version = old_random_timestamp();
          $storage->{timestamp} = $version;
          $storage->stage;
          $storage->make_object_path;
          $storage->move;
          $storage->record_backup;
        }
        my $storage = staged_volume_storage('prefixedversions-test', 'test','test');
        my $new_version = new_random_timestamp();
        $storage->{timestamp} = $new_version;
        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->record_backup;
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'prefixedversions-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 2, 'two old objects marked with feed_backups.deleted=1');
        foreach my $old_storage (@old_versions) {
          my $mets = $old_storage->mets_obj_path();
          my $zip = $old_storage->zip_obj_path();
          ok(!-e $mets, "old ($old_storage->{timestamp}) mets deleted");
          ok(!-e $zip, "old ($old_storage->{timestamp}) zip deleted");
        }
        my $mets = $storage->mets_obj_path();
        my $zip = $storage->zip_obj_path();
        ok(-e $mets, "new ($new_version) mets left intact");
        ok(-e $zip, "new ($new_version) zip left intact");
      };

      it "does not do anything with old versions if there is no new one" => sub {
        my @old_versions;
        foreach my $n (1 .. 2) {
          my $storage = staged_volume_storage('prefixedversions-test', 'test','test');
          push @old_versions, $storage;
          my $version = old_random_timestamp();
          $storage->{timestamp} = $version;
          $storage->stage;
          $storage->make_object_path;
          $storage->move;
          $storage->record_backup;
        }
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'prefixedversions-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 0, 'objects are not marked feed_backups.deleted');
        foreach my $old_storage (@old_versions) {
          my $mets = $old_storage->mets_obj_path();
          my $zip = $old_storage->zip_obj_path();
          ok(-e $mets, "old ($old_storage->{timestamp}) zip left intact");
          ok(-e $zip, "old ($old_storage->{timestamp}) mets left intact");
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
        my $storage = staged_volume_storage('objectstore-test', 'test','test');
        my $version = old_random_timestamp();
        $storage->{timestamp} = $version;
        $storage->move;
        $storage->record_backup;
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'objectstore-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND version=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $version );
        is($res[0], 0, 'object is not deleted');
        my $result = $s3->s3api('head-object','--key',"test.test.$version.zip");
        ok($result->{Metadata}, 'zip left intact');
        $result = $s3->s3api('head-object','--key',"test.test.$version.mets.xml");
        ok($result->{Metadata}, 'mets left intact');
      };

      it "deletes old versions when there is a new one" => sub {
        my @old_versions;
        foreach my $n (1 .. 2) {
          my $storage = staged_volume_storage('objectstore-test', 'test','test');
          push @old_versions, $storage;
          my $version = old_random_timestamp();
          $storage->{timestamp} = $version;
          $storage->move;
          $storage->record_backup;
        }
        my $storage = staged_volume_storage('objectstore-test', 'test','test');
        my $new_version = new_random_timestamp();
        $storage->{timestamp} = $new_version;
        $storage->move;
        $storage->record_backup;
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'objectstore-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 2, 'two old objects marked with feed_backups.deleted=1');
        foreach my $old_storage (@old_versions) {
          eval {
            $s3->s3api('head-object','--key',"test.test.$old_storage->{timestamp}.zip");
          };
          ok(defined $@ && $@ =~ m/404/, "old ($old_storage->{timestamp}) zip deleted");
          eval {
            $s3->s3api('head-object','--key',"test.test.$old_storage->{timestamp}.mets.xml");
          };
          ok(defined $@ && $@ =~ m/404/, "old ($old_storage->{timestamp}) mets deleted");
        }
        my $result = $s3->s3api('head-object','--key',"test.test.$new_version.zip");
        ok($result->{Metadata}, "new ($new_version) zip left intact");
        $result = $s3->s3api('head-object','--key',"test.test.$new_version.mets.xml");
        ok($result->{Metadata}, "new ($new_version) mets left intact");
      };

      it "does not do anything with old versions if there is no new one" => sub {
        my @old_versions;
        foreach my $n (1 .. 2) {
          my $storage = staged_volume_storage('objectstore-test', 'test','test');
          push @old_versions, $storage;
          my $version = old_random_timestamp();
          $storage->{timestamp} = $version;
          $storage->move;
          $storage->record_backup;
        }
        my $exp = HTFeed::BackupExpiration->new(storage_name => 'objectstore-test');
        $exp->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace=? AND id=? AND deleted=1';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 0, 'objects are not marked feed_backups.deleted');
        foreach my $old_storage (@old_versions) {
          my $result = $s3->s3api('head-object','--key',"test.test.$old_storage->{timestamp}.zip");
          ok($result->{Metadata}, "old ($old_storage->{timestamp}) zip left intact");
          $result = $s3->s3api('head-object','--key',"test.test.$old_storage->{timestamp}.mets.xml");
          ok($result->{Metadata}, "old ($old_storage->{timestamp}) mets left intact");
        }
      };
    };
  };
};

runtests unless caller;
