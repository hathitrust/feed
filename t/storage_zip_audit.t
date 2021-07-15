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
    $storage->cleanup;
    return $storage;
  }

  sub HTFeed::Storage::zip_auditor {
    my $self = shift;

    return HTFeed::StorageZipAudit->for_storage_name($self->{name});
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

  share my %vars;
  shared_examples_for "all storages" => sub {
    around {
      $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
      yield;
      delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
    };

    it "should create auditor" => sub {
      my $audit = $vars{storage}->zip_auditor();
      ok($audit, 'zip_auditor returns a value');
      is($audit->{storage_name}, $vars{storage}->{name}, 'zip_auditor has correct storage name');
      is(ref $audit, $vars{audit_class}, 'zip_auditor is correct class');
    };

    it "can pick random object" => sub {
      my $audit = $vars{storage}->zip_auditor();
      ok($audit, 'zip_auditor returns a value');
      my $obj = $audit->random_object();
      is($obj->{namespace}, 'test', 'random_object returns namespace "test"');
      is($obj->{objid}, 'test', 'random_object returns objid "test"');
      is($obj->{version}, $vars{storage}->{timestamp}, 'random_object returns timestamp');
      is($obj->{path}, $vars{storage}->audit_path(), 'random_object returns audit path');
    };

    it "runs successfully by default" => sub {
      my $audit = $vars{storage}->zip_auditor();
      my $errs = $audit->run();
      is($errs, 0, 'run() returns 0 errors');
    };

    it "fails when METS checksum is altered" => sub {
      my $audit = $vars{storage}->zip_auditor();
      my $obj = $audit->all_objects()->[0];
      `sed -i s/2d40d65c1aecd857b3f780e85bc9bd92/2d40d65c1aecd857b3f780e85bc9bd91/g $obj->{mets_path}`;
      my $errs = $audit->run($obj);
      is($errs, 1, 'run() returns 1 error');
      my $sql = 'SELECT COUNT(*) FROM feed_audit_detail' .
                ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
      my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
      is($res[0], 1, '1 BadChecksum error recorded');
    };

    it "fails when database checksum is altered" => sub {
      my $sql = 'UPDATE feed_backups SET saved_md5sum=?' .
                ' WHERE namespace=? AND id=? AND version=?';
      get_dbh->prepare($sql)->execute('deadbeef' x 4, 'test', 'test', $vars{storage}->{timestamp});
      my $audit = $vars{storage}->zip_auditor();
      my $errs = $audit->run();
      is($errs, 1, 'run() returns 1 error');
      $sql = 'SELECT COUNT(*) FROM feed_audit_detail' .
             ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
      my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
      is($res[0], 1, '1 BadChecksum error recorded');
    };
  };

  describe "HTFeed::StorageZipAudit with PrefixedVersions" => sub {
    before each => sub {
      $vars{storage} = prepare_storage('prefixedversions-test');
      $vars{audit_class} = 'HTFeed::StorageZipAudit';
    };

    it_should_behave_like "all storages";
  };

  describe "HTFeed::StorageZipAudit::ObjectStore" => sub {
    before each => sub {
      $vars{storage} = prepare_storage('objectstore-test');
      $vars{audit_class} = 'HTFeed::StorageZipAudit::ObjectStore';
    };

    it_should_behave_like "all storages";

    describe "#run" => sub {
      it "removes restore_request when finished" => sub {
        $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
        my $errs = $vars{storage}->zip_auditor()->run();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace = ? AND id = ? AND version = ?' .
                  ' AND restore_request IS NOT NULL';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $vars{storage}->{timestamp});
        is($res[0], 0, 'restore_request count = 0');
        delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
      };
    };

    describe "#all_objects" => sub {
      it "records restore_request for zip and METS" => sub {
        my $objects = $vars{storage}->zip_auditor()->all_objects();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace = ? AND id = ? AND version = ?' .
                  ' AND restore_request IS NOT NULL';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $vars{storage}->{timestamp});
        is($res[0], 1, 'restore_request count = 1');
      };

      it "holds on to objects that are still pending" => sub {
        $ENV{S3_HEAD_OBJECT_RESTORE_PENDING} = 1;
        my $objects = $vars{storage}->zip_auditor()->all_objects();
        is(scalar @$objects, 0, 'no objects available from Glacier');
        delete $ENV{S3_HEAD_OBJECT_RESTORE_PENDING};
      };
    };
  };
};

runtests unless caller;
