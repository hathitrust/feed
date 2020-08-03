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
      $storage->set_true(qw(stage zipvalidate prevalidate make_object_path move postvalidate record_audit cleanup rollback clean_staging));

      my $volume = HTFeed::Volume->new(namespace => 'test',
        id => 'test',
        packagetype => 'simple');
      $collate = HTFeed::Stage::Collate->new(volume => $volume);

    };

    context "when zip contents validation fails" => sub {
      before each => sub {
        $storage->set_false('zipvalidate');
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
    }
  };

  context "with real volumes" => sub {
    my $tmpdirs;
    my $testlog;

    before all => sub {
      load_db_fixtures;
      $tmpdirs = HTFeed::Test::TempDirs->new();
      $testlog = HTFeed::Test::Logger->new();
    };

    before each => sub {
      get_dbh()->do("DELETE FROM feed_audit WHERE namespace = 'test'");
      get_dbh()->do("DELETE FROM feed_backups WHERE namespace = 'test'");
      $tmpdirs->setup_example;
      $testlog->reset;
      set_config($tmpdirs->test_home . "/fixtures/volumes",'staging','fetch');
    };

    after each => sub {
      $tmpdirs->cleanup_example;
    };

    after all => sub {
      $tmpdirs->cleanup;
    };

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
      my $old_storage_classes;
      before each => sub {
        $old_storage_classes = get_config('storage_classes');
        my $new_storage_classes = [{class => 'HTFeed::Storage::LocalPairtree'},
                                   {class => 'HTFeed::Storage::VersionedPairtree'}];
        my $repo = get_config('repository');
        foreach my $class (@$new_storage_classes) {
          $class = {%$class, %$repo};
        }
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
        my $backups = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");
        is(scalar(@{$audits}),1,'records an audit');
        is(scalar(@{$backups}),1,'records a backup');

        my $timestamp = $backups->[0][0];
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml",'copies mets to local storage');
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip",'copies zip to local storage');

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$timestamp/test.zip","copies the zip to backup storage");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$timestamp/test.mets.xml","copies the mets backup storage");

        ok(! -e "$tmpdirs->{zip}/test/00000001.jp2","cleans up the extracted zip files");
        ok(! -e "$tmpdirs->{zip}/test","cleans up the zip file tmpdir");

        ok($stage->succeeded);
      };
    };
  };
};

runtests unless caller;
