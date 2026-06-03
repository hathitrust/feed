use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use File::Path qw(make_path);
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(stage_volume);
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);
use Test::MockObject;

describe "HTFeed::Collate" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);

  context "with mocked storage" => sub {
    my $storage;
    my $collate;

    sub mocked_storage {
      my $storage = Test::MockObject->new();
      $storage->set_true(qw(stage validate_zip_completeness prevalidate make_object_path move postvalidate record_audit cleanup rollback clean_staging encrypt verify_crypt));
      $storage->{name} = "mock_storage";
      $storage->{errors} = [];

      return $storage;
    }

    before each => sub {
      $storage = mocked_storage();

      my $volume = HTFeed::Volume->new(namespace => 'test',
        objid => 'test',
        packagetype => 'simple');
      $collate = HTFeed::Stage::Collate->new(volume => $volume);

      # need to have something here so record_audit will be happy
      my $obj_path = $tmpdirs->{obj_dir} . "/test/pairtree_root/te/st/test";
      make_path($obj_path);
      system("touch $obj_path/test.zip");
      system("touch $obj_path/test.mets.xml");

      get_dbh()->do("DELETE FROM feed_audit WHERE namespace = 'test'");

    };

    context "when zip contents validation fails" => sub {
      before each => sub {
        $storage->set_false('validate_zip_completeness');
      };

      it "doesn't move to staging area" => sub {
        eval { $collate->run($storage) };

        ok(!$storage->called('stage'));
      };
    };

    context "when prevalidation fails" => sub {
      before each => sub {
        $storage->set_false('prevalidate');
      };

      it "doesn't move to object storage" => sub {
        eval { $collate->run($storage) };

        ok(!$storage->called('make_object_path'));
        ok(!$storage->called('move'));
      };

      it "cleans up the staging area" => sub {
        eval { $collate->run($storage) };
        ok($storage->called('clean_staging'));
      };
    };

    context "when move fails" => sub {
      before each => sub {
        $storage->set_false('move');
      };

      it "calls rollback" => sub {
        eval { $collate->run($storage) };
        ok($storage->called('rollback'));
      };

      it "cleans up the staging area" => sub {
        eval { $collate->run($storage) };
        ok($storage->called('clean_staging'));
      };

      it "does not record to feed_audit" => sub {
        eval { $collate->run($storage) };

        my $r = get_dbh()->selectall_arrayref("SELECT first_ingest_date from feed_audit WHERE namespace = 'test' and id = 'test'");
        ok(scalar(@$r) == 0);

      }
    };

    context "when postvalidation fails" => sub {
      before each => sub {
        $storage->set_false('postvalidate');
      };

      it "rolls back to the existing version" => sub {
        eval { $collate->run($storage) };

        ok($storage->called('rollback'));
      };

      it "does not record an audit" => sub {
        eval { $collate->run($storage) };

        ok(!$storage->called('record_audit'));
      };

      it "cleans up the staging area" => sub {
        eval { $collate->run($storage) };
        ok($storage->called('clean_staging'));
      };
    };

    it "rolls back first storage if second storage fails" => sub {
      my $storage1 = mocked_storage();
      $storage1->{name} = "storage1";
      my $storage2 = mocked_storage();
      $storage2->{name} = "storage2";
      $storage2->set_false('postvalidate');

      eval { $collate->run($storage1,$storage2) };
      ok($storage1->called('rollback'));
      ok($storage2->called('rollback'));
    };

    context "when everything succeeds" => sub {
      it "encrypts the item" => sub {
        $collate->run($storage);
        ok($storage->called('encrypt'));
      };

      it "verifies the encrypted item" => sub {
        $collate->run($storage);
        ok($storage->called('verify_crypt'));
      };

      it "cleans up" => sub {
        $collate->run($storage);
        ok($storage->called('cleanup'));
      };

      it "cleans up the staging area" => sub {
        $collate->run($storage);
        ok($storage->called('clean_staging'));
      };

      it "records an audit" => sub {
        $collate->run($storage);
        ok($storage->called('record_audit'));
      };

      it "reports stage success" => sub {
        $collate->run($storage);
        ok($collate->succeeded());
      };

      it "does not roll back" => sub {
        $collate->run($storage);
        ok(!$storage->called('rollback'));
      };

      it "records ingest date in feed_audit" => sub {
        $collate->run($storage);

        my $r = get_dbh()->selectall_arrayref("SELECT first_ingest_date from feed_audit WHERE namespace = 'test' and id = 'test'");
        ok($r->[0][0]);

      };
    };


    context "when encryption fails" => sub {
      before each => sub {
        $storage->set_false('encrypt');
      };

      it "doesn't move to staging" => sub { 
        eval { $collate->run($storage); };
        ok(!$storage->called('stage'));
      };
    };

    context "when verifying the encrypted zip fails" => sub {
      before each => sub {
        $storage->set_false('encrypt');
      };

      it "doesn't move to staging" => sub { 
        eval { $collate->run($storage); };
        ok(!$storage->called('stage'));
      };
    };
  };

  context "with real volumes" => sub {
    it "logs a repeat when collated twice" => sub {
      my $volume = stage_volume($tmpdirs,'test','test');
      my $storage = HTFeed::Storage::LocalPairtree->new(
        volume => $volume, 
        config => { obj_dir => get_config('repository_root') },
        name => "localpairtree_test"
      );
      my $stage = HTFeed::Stage::Collate->new(volume => $volume);
      $stage->run($storage);

      # collate same thing again
      $stage = HTFeed::Stage::Collate->new(volume => $volume);
      $stage->run($storage);

      ok($testlog->matches(qw(INFO.*already in repo)));
    };

    context "with multiple real storage classes" => sub {
      spec_helper 's3_helper.pl';

      local our ($bucket, $s3);
      my $old_storage_classes;
      my $old_repository_root;
      my %s3s;

      before all => sub {
        foreach my $suffix (qw(ptobj1 ptobj2 backup)) {
          $s3s{$suffix} = HTFeed::Storage::S3->new(
            bucket => "$bucket-$suffix",
            awscli => get_config('awscli')
          );
          $s3s{$suffix}->mb;
        }
      };

      after all => sub {
        foreach my $s3 (values(%s3s)) {
          $s3->rm('/',"--recursive");
          $s3->rb;
        }
      };

      before each => sub {
        $old_storage_classes = get_config('storage_classes');
        $old_repository_root = get_config('repository_root');

        my $backup_dir = $tmpdirs->dir_for("backup");

        my $new_storage_classes = {
          # simulating truenas (site 1)
          'pairtreeobjectstore-ptobj1' => {
            class => 'HTFeed::Storage::PairtreeObjectStore',
            bucket => $s3s{ptobj1}->{bucket},
            awscli => $s3s{ptobj1}->{awscli},
          },
          # simulating truenas (site 2)
          'pairtreeobjectstore-ptobj2' => {
            class => 'HTFeed::Storage::PairtreeObjectStore',
            bucket => $s3s{ptobj2}->{bucket},
            awscli => $s3s{ptobj2}->{awscli},
          },
          # simulating data den
          'prefixedversions-test' =>
          {
            class => 'HTFeed::Storage::PrefixedVersions',
            obj_dir => $backup_dir,
            encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
          },
          # simulating glacier deep archive
          'objectstore-test' =>
          {
            class => 'HTFeed::Storage::ObjectStore',
            bucket => $s3s{backup}->{bucket},
            awscli => $s3s{backup}->{awscli},
            encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
          }
        };

        my $vgw_home = "$ENV{FEED_HOME}/var/vgw";
        my $bucket_dir = "$vgw_home/$s3s{ptobj1}->{bucket}";

        set_config($new_storage_classes,'storage_classes');
        set_config($bucket_dir, 'repository_root');
      };

      after each => sub {
        set_config($old_storage_classes,'storage_classes');
        set_config($old_repository_root,'repository_root');
      };

      it "copies and records to all configured storages" => sub {
        my $volume = stage_volume($tmpdirs,'test','test');
        my $stage = HTFeed::Stage::Collate->new(volume => $volume);
        $stage->run;

        my $dbh = get_dbh();
        my $audits = $dbh->selectall_arrayref("SELECT * from feed_audit WHERE namespace = 'test' and id = 'test'");
        my $versioned_backup = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test' and path like ?",undef,$tmpdirs->{backup} . '%');
        my $s3_backup = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test' and path like ?",undef,"s3://$bucket%");

        is(scalar(@{$audits}),1,'records an audit');
        is(scalar(@{$versioned_backup}),1,'records a backup for versioned pairtree');
        is(scalar(@{$s3_backup}),1,'records a backup for object store');

        my $timestamp = $versioned_backup->[0][0];

        my $pt_path = "test/pairtree_root/te/st/test";

        ok(-e "$tmpdirs->{backup}/test/tes/test.$timestamp.zip.gpg","copies the encrypted zip to backup storage");
        ok(-e "$tmpdirs->{backup}/test/tes/test.$timestamp.mets.xml","copies the mets backup storage");

        my $s3_timestamp = $s3_backup->[0][0];

        ok($s3s{ptobj1}->s3_has("$pt_path/test.mets.xml"));
        ok($s3s{ptobj1}->s3_has("$pt_path/test.zip"));
        ok($s3s{ptobj2}->s3_has("$pt_path/test.mets.xml"));
        ok($s3s{ptobj2}->s3_has("$pt_path/test.zip"));
        ok($s3s{backup}->s3_has("test.test.$s3_timestamp.zip.gpg"));
        ok($s3s{backup}->s3_has("test.test.$s3_timestamp.mets.xml"));

        ok(! -e "$tmpdirs->{zip}/test/00000001.jp2","cleans up the extracted zip files");
        ok(! -e "$tmpdirs->{zip}/test","cleans up the zip file tmpdir");

        ok($stage->succeeded);
      };

    };

  };
};

runtests unless caller;
