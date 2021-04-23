use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(stage_volume);
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);
use Test::MockObject;

describe "HTFeed::Collate" => sub {

  context "with mocked storage" => sub {
    my $storage;
    my $collate;

    before each => sub {
      $storage = Test::MockObject->new();
      $storage->set_true(qw(stage validate_zip_completeness prevalidate make_object_path move postvalidate record_audit cleanup rollback clean_staging encrypt verify_crypt));

      my $volume = HTFeed::Volume->new(namespace => 'test',
        id => 'test',
        packagetype => 'simple');
      $collate = HTFeed::Stage::Collate->new(volume => $volume);

    };

    context "when zip contents validation fails" => sub {
      before each => sub {
        $storage->set_false('validate_zip_completeness');
      };

      it "doesn't move to staging area" => sub {
        $collate->run($storage);

        ok(!$storage->called('stage'));
      };
    };

    context "when prevalidation fails" => sub {
      before each => sub {
        $storage->set_false('prevalidate');
      };

      it "doesn't move to object storage" => sub {
        $collate->run($storage);

        ok(!$storage->called('make_object_path'));
        ok(!$storage->called('move'));
      };

      it "cleans up the staging area" => sub {
        $collate->run($storage);
        ok($storage->called('clean_staging'));
      };
    };

    context "when move fails" => sub {
      before each => sub {
        $storage->set_false('move');
      };

      it "calls rollback" => sub {
        $collate->run($storage);
        ok($storage->called('rollback'));
      };

      it "cleans up the staging area" => sub {
        $collate->run($storage);
        ok($storage->called('clean_staging'));
      };
    };

    context "when postvalidation fails" => sub {
      before each => sub {
        $storage->set_false('postvalidate');
      };

      it "rolls back to the existing version" => sub {
        $collate->run($storage);

        ok($storage->called('rollback'));
      };

      it "does not record an audit" => sub {
        $collate->run($storage);

        ok(!$storage->called('record_audit'));
      };

      it "cleans up the staging area" => sub {
        $collate->run($storage);
        ok($storage->called('clean_staging'));
      };
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
      }
    };


    context "when encryption fails" => sub {
      before each => sub {
        $storage->set_false('encrypt');
      };

      it "doesn't move to staging" => sub { 
        $collate->run($storage);
        ok(!$storage->called('stage'));
      };
    };

    context "when verifying the encrypted zip fails" => sub {
      before each => sub {
        $storage->set_false('encrypt');
      };

      it "doesn't move to staging" => sub { 
        $collate->run($storage);
        ok(!$storage->called('stage'));
      };
    };
  };

  context "with real volumes" => sub {
    spec_helper 'storage_helper.pl';

    local our ($tmpdirs, $testlog);

    it "logs a repeat when collated twice" => sub {
      my $volume = stage_volume($tmpdirs,'test','test');
      my $stage = HTFeed::Stage::Collate->new(volume => $volume);
      $stage->run;

      # collate same thing again
      $stage = HTFeed::Stage::Collate->new(volume => $volume);
      $stage->run;

      ok($testlog->matches(qw(INFO.*already in repo)));
    };

    context "with multiple real storage classes" => sub {
      spec_helper 's3_helper.pl';

      local our ($bucket, $s3);
      my $old_storage_classes;

      before each => sub {
        $old_storage_classes = get_config('storage_classes');
        my $new_storage_classes = [
          {
            class => 'HTFeed::Storage::LinkedPairtree',
            obj_dir => $tmpdirs->{obj_dir},
            link_dir => $tmpdirs->{link_dir}
          },
          {
            class => 'HTFeed::Storage::PrefixedVersions',
            obj_dir => $tmpdirs->{backup_obj_dir},
            encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
          },
          {
            class => 'HTFeed::Storage::ObjectStore',
            bucket => $s3->{bucket},
            awscli => $s3->{awscli},
            encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
          }
        ];
        set_config($new_storage_classes,'storage_classes');
      };

      after each => sub {
        set_config($old_storage_classes,'storage_classes');
      };

      it "copies and records to all configured storages" => sub {
        my $volume = stage_volume($tmpdirs,'test','test');
        my $stage = HTFeed::Stage::Collate->new(volume => $volume);
        $stage->run;

        my $dbh = get_dbh();
        my $audits = $dbh->selectall_arrayref("SELECT * from feed_audit WHERE namespace = 'test' and id = 'test'");
        my $versioned_backup = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test' and path like ?",undef,$tmpdirs->{backup_obj_dir} . '%');
        my $s3_backup = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test' and path like ?",undef,"s3://$bucket%");

        is(scalar(@{$audits}),1,'records an audit');
        is(scalar(@{$versioned_backup}),1,'records a backup for versioned pairtree');
        is(scalar(@{$s3_backup}),1,'records a backup for object store');

        my $timestamp = $versioned_backup->[0][0];
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml",'copies mets to local storage');
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip",'copies zip to local storage');

        ok(-e "$tmpdirs->{backup_obj_dir}/test/tes/test.$timestamp.zip.gpg","copies the encrypted zip to backup storage");
        ok(-e "$tmpdirs->{backup_obj_dir}/test/tes/test.$timestamp.mets.xml","copies the mets backup storage");

        my $s3_timestamp = $s3_backup->[0][0];

        ok($s3->s3_has("test.test.$s3_timestamp.zip.gpg"));
        ok($s3->s3_has("test.test.$s3_timestamp.mets.xml"));

        ok(! -e "$tmpdirs->{zip}/test/00000001.jp2","cleans up the extracted zip files");
        ok(! -e "$tmpdirs->{zip}/test","cleans up the zip file tmpdir");

        ok($stage->succeeded);
      };

    };

  };
};

runtests unless caller;
