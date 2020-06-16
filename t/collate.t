use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport;
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);

describe "HTFeed::Stage::Collate" => sub {
  my $tmpdirs;
  my $testlog;

  sub setup_dirs {
    my $tmpdirs = shift;
    my $namespace = shift;
    my $objid = shift;

    my $mets = $tmpdirs->test_home . "/fixtures/collate/$objid.mets.xml";
    my $zip = $tmpdirs->test_home . "/fixtures/collate/$objid.zip";
    system("cp $mets $tmpdirs->{ingest}");
    mkdir("$tmpdirs->{zipfile}/$objid");
    system("cp $zip $tmpdirs->{zipfile}/$objid");

    my $volume = HTFeed::Volume->new(
      namespace => $namespace,
      objid => $objid,
      packagetype => 'simple');
  }

  sub collate {
    my $storage = shift;

    my $stage = HTFeed::Stage::Collate->new(volume => $storage->{volume});

    $stage->run($storage);
  }

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
    set_config($tmpdirs->test_home . "/fixtures/collate",'staging','fetch');
  };

  after each => sub {
    $tmpdirs->cleanup_example;
  };

  after all => sub {
    $tmpdirs->cleanup;
  };

  # TODO test collate with stubbed-out storage
  # TODO integration test for collate with local & versioned pairtree
  #
  describe "HTFeed::Stage::Collate" => sub {
    it "doesn't move if validation fails";

    it "rolls back to the existing version if postvalidation fails";

    it "records nothing in feed_audit if postvalidation fails";
  };

  describe "HTFeed::Storage::LocalPairtree" => sub {
    use HTFeed::Storage::LocalPairtree;

    sub local_storage {
      my $volume = setup_dirs(@_);

      my $storage = HTFeed::Storage::LocalPairtree->new(
        volume => $volume);

      return $storage;
    }

    describe "#move" => sub {
      it "copies the mets and zip to the repository" => sub {
        collate(local_storage($tmpdirs,'test','test'));

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip");
      };
    };

    describe "#make_object_path" => sub {
      it "creates a symlink for the volume" => sub {
        collate(local_storage($tmpdirs,'test','test'));

        is("$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test",
          readlink("$tmpdirs->{link_dir}/test/pairtree_root/te/st/test"));
      };
    };

    describe "#validate" => sub {
      it "does not copy or symlink a zip whose checksum does not match the one in the METS to the repository" => sub {
        eval { collate(local_storage($tmpdirs,'test','bad_zip')) };

        ok($testlog->matches(qr(ERROR.*Checksum.*bad_zip.zip)));
        ok(!-e "$tmpdirs->{obj_dir}/test/pairtree_root/ba/d_/zi/p/bad_zip/bad_zip.mets.xml");
        ok(!-e "$tmpdirs->{obj_dir}/test/pairtree_root/ba/d_/zi/p/bad_zip/bad_zip.zip");
      };
    };

    it "does not copy or symlink a zip whose contents do not match the METS to the repository";


    it "records an md5 check in the feed_audit table" => sub {
      my $dbh = get_dbh();

      collate(local_storage($tmpdirs,'test','test'));

      my $r = $dbh->selectall_arrayref("SELECT lastmd5check from feed_audit WHERE namespace = 'test' and id = 'test'");

      ok($r->[0][0]);

    };

  };

  describe "HTFeed::Storage::VersionedPairtree" => sub {
    use HTFeed::Storage::VersionedPairtree;

    sub versioned_storage {
      my $volume = setup_dirs(@_);

      my $storage = HTFeed::Storage::VersionedPairtree->new(
        volume => $volume);

      return $storage;
    }


    describe "#object_path" => sub {

      it "uses config for object root" => sub {
        my $old_storage = get_config('repository','backup_obj_dir');
        set_config('/backup-location/obj','repository','backup_obj_dir');

        eval {
          my $storage = versioned_storage($tmpdirs, 'test', 'test');
          like( $storage->object_path(), qr{^/backup-location/obj/});
        };

        set_config($old_storage, 'repository','backup_obj_dir');
      };

      it "includes the namespace and pairtreeized object id in the path" => sub {
        my $storage = versioned_storage($tmpdirs, 'test', 'test');

        like( $storage->object_path(), qr{/test/pairtree_root/te/st/test});
      };

      it "includes a datestamp in the object directory" => sub {
        my $storage = versioned_storage($tmpdirs,'test','test');

        like( $storage->object_path(), qr{/test/\d{14}});
      };
    };

    describe "#stage" => sub {
      it "deposits to a staging area under the configured object location" => sub {
        my $storage = versioned_storage($tmpdirs, 'test', 'test');
        $storage->stage;

        ok(-e "$tmpdirs->{backup_obj_stage_dir}/test.test/test.mets.xml");
        ok(-e "$tmpdirs->{backup_obj_stage_dir}/test.test/test.zip");
      }
    };

    describe "#validate" => sub {
      it "returns false and logs for a corrupted zip" => sub {
        my $storage = versioned_storage($tmpdirs, 'test', 'bad_zip');
        $storage->stage;

        eval { not_ok($storage->validate); };
        ok($testlog->matches(qr(ERROR.*Checksum.*bad_zip.zip)));
      };

      it "returns true for a zip matching the checksum in the METS" => sub {
        my $storage = versioned_storage($tmpdirs, 'test', 'test');
        $storage->stage;

        ok($storage->validate);
      }
    };

    describe "#make_object_path" => sub {
      it "makes the path with a timestamp" => sub {
        my $storage = versioned_storage($tmpdirs, 'test','test');

        $storage->make_object_path;

        ok(-d "$tmpdirs->{backup_obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}");
      }
    };

    describe "#move" => sub {
      it "moves from the staging location to the object path" => sub {
        my $storage = versioned_storage($tmpdirs,'test','test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok(-e "$tmpdirs->{backup_obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}/test.zip","copies the zip");
        ok(-e "$tmpdirs->{backup_obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}/test.mets.xml","copies the mets");
      };
    };

    describe "#cleanup" => sub {
      it "cleans up the staging dir" => sub {
        my $storage = versioned_storage($tmpdirs,'test','test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->cleanup;

        ok(! -e "$tmpdirs->{backup_obj_stage_dir}/test.test","cleans up the staging dir");
      }
    };

    describe "#record_backup" => sub {
      it "records the copy in the feed_backups table" => sub {
        my $storage = versioned_storage($tmpdirs,'test','test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->record_backup;

        my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

        is($r->[0][0],$storage->{timestamp});
      };

      it "does not record anything in feed_backups if the volume wasn't moved" => sub {

        my $storage = versioned_storage($tmpdirs,'test','test');
        $storage->stage;

        eval { $storage->record_backup };

        my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

        is(scalar(@$r),0);

      };
    }
  };
};

runtests unless caller;
