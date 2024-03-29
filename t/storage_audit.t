use POSIX qw(strftime);
use Test::Spec;
use HTFeed::DBTools qw(get_dbh);
use HTFeed::StorageAudit;
use HTFeed::Storage::PrefixedVersions;
use HTFeed::Storage::ObjectStore;

use strict;

describe "HTFeed::StorageAudit" => sub {
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
        obj_dir => $tmpdirs->{backup_obj_dir} . '/obj',
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
    my $skip_record_backup = shift;
    my $version = shift;

    my $volume = stage_volume($tmpdirs, 'test', 'test');
    my $storage_config = get_config('storage_classes')->{$storage_name};
    my $storage = $storage_config->{class}->new(volume    => $volume,
                                                config    => $storage_config,
                                                name      => $storage_name,
                                                timestamp => $version);
    $storage->encrypt;
    $storage->stage;
    $storage->make_object_path;
    $storage->move;
    $storage->record_backup unless $skip_record_backup;
    $storage->cleanup;
    return $storage;
  }

  sub add_bogus_feed_backups_entry {
    my $storage_name = shift;

    my @chars = ("a".."z");
    my $fake_objid;
    $fake_objid .= $chars[rand @chars] for 1..8;

    my $version = strftime("%Y%m%d%H%M%S", gmtime);
    my $sql = 'INSERT INTO feed_backups (namespace, id, path, version, storage_name)' .
              'VALUES (?,?,?,?,?)';
    my $sth  = get_dbh->prepare($sql);
    $sth->execute('test', $fake_objid, "s3://" . $s3->{bucket} . "/" . $version,
                  $version, $storage_name);
    return $version;
  }

  # A random meaningless timespamp/version.
  sub random_version {
    return join('', map { int rand 10 } (1 .. 14));
  }

  sub delete_zip {
    my $storage = shift;

    if ($storage->{name} eq 'objectstore-test') {
      $storage->{s3}->rm('/' . $storage->zip_key);
    } else {
      unlink $storage->object_path . '/' . $storage->zip_filename;
    }
  }

  sub delete_mets {
    my $storage = shift;

    if ($storage->{name} eq 'objectstore-test') {
      $storage->{s3}->rm('/' . $storage->mets_key);
    } else {
      unlink $storage->object_path . '/' . $storage->mets_filename;
    }
  }

  no warnings 'redefine';
  # These next subs may redefine existing subs,
  # suppressing warnings.
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

  sub HTFeed::Storage::auditor {
    my $self = shift;

    return HTFeed::StorageAudit->for_storage_name($self->{name});
  }
  use warnings 'redefine';

  share my %vars;
  shared_examples_for "all storages" => sub {
    around {
      $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
      yield;
      delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
    };

    it "should create auditor" => sub {
      my $audit = $vars{storage}->auditor();
      ok($audit, 'auditor returns a value');
      is($audit->{storage_name}, $vars{storage}->{name}, 'auditor has correct storage name');
      is(ref $audit, $vars{audit_class}, 'auditor is correct class');
    };

    it "can pick random object" => sub {
      my $audit = $vars{storage}->auditor();
      ok($audit, 'auditor returns a value');
      my $obj = $audit->random_object();
      is($obj->{namespace}, 'test', 'random_object returns namespace "test"');
      is($obj->{objid}, 'test', 'random_object returns objid "test"');
      is($obj->{version}, $vars{storage}->{timestamp}, 'random_object returns timestamp');
      is($obj->{path}, $vars{storage}->audit_path(), 'random_object returns audit path');
    };

    it "runs fixity check successfully" => sub {
      my $audit = $vars{storage}->auditor();
      my $errs = $audit->run_fixity_check();
      is($errs, 0, 'run_fixity_check returns 0 errors');
    };

    it "fails fixity check when METS checksum is altered" => sub {
      my $audit = $vars{storage}->auditor();
      my $obj = $audit->objects_to_audit()->[0];
      `sed -i s/2d40d65c1aecd857b3f780e85bc9bd92/2d40d65c1aecd857b3f780e85bc9bd91/g $obj->{mets_path}`;
      my $errs = $audit->run_fixity_check($obj);
      is($errs, 1, 'run_fixity_check returns 1 error');
      my $sql = 'SELECT COUNT(*) FROM feed_audit_detail' .
                ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
      my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
      is($res[0], 1, '1 BadChecksum error recorded');
    };

    it "fails fixity check when database checksum is altered" => sub {
      my $sql = 'UPDATE feed_backups SET saved_md5sum=?' .
                ' WHERE namespace=? AND id=? AND version=?';
      get_dbh->prepare($sql)->execute('deadbeef' x 4, 'test', 'test', $vars{storage}->{timestamp});
      my $audit = $vars{storage}->auditor();
      my $errs = $audit->run_fixity_check();
      is($errs, 1, 'run_fixity_check returns 1 error');
      $sql = 'SELECT COUNT(*) FROM feed_audit_detail' .
             ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
      my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test');
      is($res[0], 1, '1 BadChecksum error recorded');
    };

    it "iterates storage objects without duplication" => sub {
      prepare_storage($vars{storage}->{name}, 0, random_version());
      prepare_storage($vars{storage}->{name}, 0, random_version());
      prepare_storage($vars{storage}->{name}, 0, random_version());
      prepare_storage($vars{storage}->{name}, 0, random_version());
      my $audit = $vars{storage}->auditor();
      my $iterator = $audit->object_iterator;
      my $count = 0;
      while (my $obj = $iterator->()) {
        $count++;
      }
      is($count, 5, 'iterator returns 5 objects');
    };

    it "runs database completeness check successfully" => sub {
      my $audit = $vars{storage}->auditor();
      my $errs = $audit->run_database_completeness_check();
      is($errs, 0, 'no errors reported');
    };

    it "fails database completeness check for object not recorded" => sub {
      prepare_storage($vars{storage}->{name}, 1, random_version());
      my $audit = $vars{storage}->auditor();
      my $errs = $audit->run_database_completeness_check();
      is($errs, 1, '1 error reported');
    };

      it "fails database completeness check on missing zip" => sub {
        delete_zip($vars{storage});
        my $audit = $vars{storage}->auditor();
        my $errs = $audit->run_database_completeness_check();
        is($errs, 1, '1 error reported');
      };

      it "fails database completeness check on missing mets" => sub {
        delete_mets($vars{storage});
        my $audit = $vars{storage}->auditor();
        my $errs = $audit->run_database_completeness_check();
        is($errs, 1, '1 error reported');
      };

    it "runs storage completeness check successfully" => sub {
      my $audit = $vars{storage}->auditor();
      my $errs = $audit->run_storage_completeness_check();
      is($errs, 0, 'no errors reported');
    };

    it "fails storage completeness check on bogus feed_backups entry" => sub {
      my $version = add_bogus_feed_backups_entry($vars{storage}->{name});
      my $audit = $vars{storage}->auditor();
      my $errs = $audit->run_storage_completeness_check();
      is($errs, 2, '2 errors reported');
      ok($testlog->matches(qr(ERROR.+?$version)s), 'errors reported for incomplete storage entries');
    };
  };

  describe "HTFeed::StorageAudit::PrefixedVersions" => sub {
    before each => sub {
      $vars{storage} = prepare_storage('prefixedversions-test');
      $vars{audit_class} = 'HTFeed::StorageAudit::PrefixedVersions';
    };

    it_should_behave_like "all storages";

    it "updates lastmd5check on successful fixity check" => sub {
      my $audit = $vars{storage}->auditor();
      my $obj = $audit->random_object();
      my @sql_args = ($obj->{namespace},$obj->{objid},$obj->{version},$vars{storage}->{name});

      # backdate lastmd5check
      my $update_sql = 'UPDATE feed_backups SET lastmd5check = ?' .
                ' WHERE namespace = ? AND id = ? and version = ? and storage_name = ?';
      get_dbh->prepare($update_sql)->execute('2008-01-01 00:00:00',@sql_args);

      my $sql = 'SELECT lastmd5check FROM feed_backups' .
                ' WHERE namespace = ? AND id = ? and version = ? and storage_name = ?';

      my $prev_lastmd5check = (get_dbh->selectrow_array($sql,undef,@sql_args))[0];

      $audit->run_fixity_check($obj);

      my $new_lastmd5check = (get_dbh->selectrow_array($sql,undef,@sql_args))[0];
      is($new_lastmd5check ne $prev_lastmd5check,1,'lastmd5check is updated');
    };

  };

  describe "HTFeed::StorageAudit::ObjectStore" => sub {
    before each => sub {
      $s3->rm('/', '--recursive');
      $vars{storage} = prepare_storage('objectstore-test');
      $vars{audit_class} = 'HTFeed::StorageAudit::ObjectStore';
    };

    it_should_behave_like "all storages";

    describe "#run_fixity_check" => sub {
      it "removes restore_request when finished" => sub {
        $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
        my $errs = $vars{storage}->auditor()->run_fixity_check();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace = ? AND id = ? AND version = ?' .
                  ' AND restore_request IS NOT NULL';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $vars{storage}->{timestamp});
        is($res[0], 0, 'restore_request count = 0');
        delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
      };
    };

    describe "#objects_to_audit" => sub {
      it "records restore_request for zip and METS" => sub {
        my $objects = $vars{storage}->auditor()->objects_to_audit();
        my $sql = 'SELECT COUNT(*) FROM feed_backups' .
                  ' WHERE namespace = ? AND id = ? AND version = ?' .
                  ' AND restore_request IS NOT NULL';
        my @res = get_dbh->selectrow_array($sql, undef, 'test', 'test', $vars{storage}->{timestamp});
        is($res[0], 1, 'restore_request count = 1');
      };

      it "holds on to objects that are still pending" => sub {
        $ENV{S3_HEAD_OBJECT_RESTORE_PENDING} = 1;
        my $objects = $vars{storage}->auditor()->objects_to_audit();
        is(scalar @$objects, 0, 'no objects available from Glacier');
        delete $ENV{S3_HEAD_OBJECT_RESTORE_PENDING};
      };
    };
  };
};

runtests unless caller;
