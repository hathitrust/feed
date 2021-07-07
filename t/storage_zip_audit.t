use Test::Spec;
use HTFeed::DBTools qw(get_dbh);
use HTFeed::StorageZipAudit;
use HTFeed::Storage::PrefixedVersions;
use HTFeed::Storage::ObjectStore;

use strict;

describe "HTFeed::StorageZipAudit" => sub {
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

    my $volume = stage_volume($tmpdirs, 'test', 'test');
    my $storage_config = get_config('storage_classes')->{$storage_name};
    my $storage = $storage_config->{class}->new(volume => $volume,
                                                config => $storage_config,
                                                name   => $storage_name);
    $storage->encrypt;
    $storage->stage;
    $storage->make_object_path;
    $storage->move;
    $storage->record_backup;
    return $storage;
  }
  
  sub audit_for_storage {
    my $storage = shift;

    return HTFeed::StorageZipAudit->new($storage->{name});
  }

  sub HTFeed::Storage::S3::restore_object {
    return 1;
  }

  sub HTFeed::Storage::S3::head_object {
    my $self = shift;
    my $key = shift;
    if ($ENV{S3_HEAD_OBJECT_RESTORE_PENDING}) {
      return {Restore => 'ongoing-request="true"'};
    }
    elsif ($ENV{S3_HEAD_OBJECT_RESTORE_DONE}) {
      return {Restore => 'ongoing-request="false"'};
    }
    return $self->s3api('head-object','--key',$key,@_);
  }

  describe "HTFeed::StorageZipAudit::PrefixedVersions" => sub {
    describe "#new" => sub {
      it "succeeds" => sub {
        my $storage = prepare_storage('prefixedversions-test');
        my $audit = audit_for_storage($storage);
        ok($audit, 'new returns a value');
        is($audit->{storage_name}, 'prefixedversions-test', 'new returns correct storage name');
        ok(ref $audit eq 'HTFeed::StorageZipAudit::PrefixedVersions', 'new returns correct class');
      };
    };
  
    describe "random_object" => sub {
      it "succeeds" => sub {
        my $storage = prepare_storage('prefixedversions-test');
        my $audit = audit_for_storage($storage);
        my $obj = $audit->random_object();
        is($obj->{namespace}, 'test', 'random_object returns namespace "test"');
        is($obj->{objid}, 'test', 'random_object returns objid "test"');
        is($obj->{version}, $storage->{timestamp}, 'random_object returns timestamp');
        is($obj->{path}, $storage->audit_path(), 'random_object returns audit path');
      };
    };

    describe "#run" => sub {
      it "succeeds" => sub {
        my $storage = prepare_storage('prefixedversions-test');
        my $audit = audit_for_storage($storage);
        my $errs = $audit->run();
        is($errs, 0, 'run() returns 0 errors');
      };

      it "fails when METS checksum is altered" => sub {
        my $storage = prepare_storage('prefixedversions-test');
        my $mets_file = $storage->object_path() . '/' . $storage->mets_filename();
        `sed -i s/2d40d65c1aecd857b3f780e85bc9bd92/2d40d65c1aecd857b3f780e85bc9bd91/g $mets_file`;
        my $audit = audit_for_storage($storage);
        my $errs = $audit->run();
        is($errs, 1, 'run() returns 1 error');
        my $sql = 'SELECT COUNT(*) FROM feed_audit_detail' . 
                  ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 1, 'BadChecksum error recorded');
      };

      it "fails when database checksum is altered" => sub {
        my $storage = prepare_storage('prefixedversions-test');
        my $sql = 'UPDATE feed_backups SET saved_md5sum=?' .
                  ' WHERE namespace=? AND id=? AND version=?';
        get_dbh->prepare($sql)->execute('deadbeef' x 4, 'test', 'test', $storage->{timestamp});
        my $audit = audit_for_storage($storage);
        my $errs = $audit->run();
        is($errs, 1, 'run() returns 1 error');
        $sql = 'SELECT COUNT(*) FROM feed_audit_detail' . 
               ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 1, 'BadChecksum error recorded');
      };
    };
  };

  describe "HTFeed::StorageZipAudit::ObjectStore" => sub {
    describe "#new" => sub {
      it "succeeds" => sub {
        my $storage = prepare_storage('objectstore-test');
        my $audit = audit_for_storage($storage);
        ok($audit, 'new returns a value');
        is($audit->{storage_name}, 'objectstore-test', 'new returns correct storage name');
        is(ref $audit, 'HTFeed::StorageZipAudit::ObjectStore', 'new returns correct class');
      };
    };

    describe "#random_object" => sub {
      it "succeeds" => sub {
        my $storage = prepare_storage('objectstore-test');
        my $audit = audit_for_storage($storage);
        my $obj = $audit->random_object();
        is($obj->{namespace}, 'test', 'random_object returns namespace "test"');
        is($obj->{objid}, 'test', 'random_object returns objid "test"');
        is($obj->{version}, $storage->{timestamp}, 'random_object returns timestamp');
        is($obj->{path}, $storage->audit_path(), 'random_object returns audit path');
      };
    };

    describe "#all_objects" => sub {
      it "records restore_request for zip and METS" => sub {
        my $storage = prepare_storage('objectstore-test');
        my $audit = audit_for_storage($storage);
        my $objects = $audit->all_objects();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' . 
                  ' WHERE namespace = ? AND id = ? AND version = ?' .
                  ' AND restore_request IS NOT NULL';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $storage->{timestamp});
        is($res[0], 1, 'restore_request count = 1');
      };
    };

    describe "#run" => sub {
      it "succeeds" => sub {
        my $storage = prepare_storage('objectstore-test');
        $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
        my $audit = audit_for_storage($storage);
        my $errs = $audit->run();
        is($errs, 0, 'run() returns 0 errors');
        delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
      };

      it "removes restore_request when finished" => sub {
        my $storage = prepare_storage('objectstore-test');
        $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
        my $audit = audit_for_storage($storage);
        my $errs = $audit->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' . 
                  ' WHERE namespace = ? AND id = ? AND version = ?' .
                  ' AND restore_request IS NOT NULL';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $storage->{timestamp});
        is($res[0], 0, 'restore_request count = 0');
        delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
      };

      it "fails when METS checksum is altered" => sub {
        my $storage = prepare_storage('objectstore-test');
        my $audit = audit_for_storage($storage);
        $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
        my $obj = $audit->all_objects()->[0];
        `sed -i s/2d40d65c1aecd857b3f780e85bc9bd92/2d40d65c1aecd857b3f780e85bc9bd91/g $obj->{mets_path}`;
        my $errs = $audit->run($obj);
        is($errs, 1, 'run() returns 1 error');
        my $sql = 'SELECT COUNT(*) FROM feed_audit_detail' . 
                  ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 1, 'BadChecksum error recorded');
        delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
      };

      it "fails when database checksum is altered" => sub {
        my $storage = prepare_storage('objectstore-test');
        my $sql = 'UPDATE feed_backups SET saved_md5sum=?' .
                  ' WHERE namespace=? AND id=? AND version=?';
        get_dbh->prepare($sql)->execute('deadbeef' x 4, 'test', 'test', $storage->{timestamp});
        my $audit = audit_for_storage($storage);
        $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
        my $errs = $audit->run();
        is($errs, 1, 'run() returns 1 error');
        $sql = 'SELECT COUNT(*) FROM feed_audit_detail' . 
               ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
        is($res[0], 1, 'BadChecksum error recorded');
        delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
      };
    };
  };
};

runtests unless caller;

