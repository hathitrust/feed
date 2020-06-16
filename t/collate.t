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

  sub setup_stage {
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

    my $stage = HTFeed::Stage::Collate->new(volume => $volume);

    return $stage;
  }

  sub collate_item {
    my $stage = setup_stage(@_);
    $stage->run();

    return $stage;

  }

  before all => sub {
    load_db_fixtures;
    $tmpdirs = HTFeed::Test::TempDirs->new();
    $testlog = HTFeed::Test::Logger->new();
  };

  before each => sub {
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

  describe "HTFeed::Storage::LocalPairtree" => sub {
    it "copies the mets and zip to the repository" => sub {
      collate_item($tmpdirs,'test','test');
      ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml");
      ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip");
    };

    it "creates a symlink for the volume" => sub {
      collate_item($tmpdirs,'test','test');
      is("$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test",
        readlink("$tmpdirs->{link_dir}/test/pairtree_root/te/st/test"));
    };

    it "does not copy or symlink a zip whose checksum does not match the one in the METS to the repository" => sub {
      eval { collate_item($tmpdirs,'test','bad_zip') };
      ok($testlog->matches(qr(ERROR.*Checksum.*bad_zip.zip)));
      ok(!-e "$tmpdirs->{obj_dir}/test/pairtree_root/ba/d_/zi/p/bad_zip/bad_zip.mets.xml");
      ok(!-e "$tmpdirs->{obj_dir}/test/pairtree_root/ba/d_/zi/p/bad_zip/bad_zip.zip");
    };

    it "does not copy or symlink a zip whose contents do not match the METS to the repository";

    it "records the audit with md5 check in feed_audit";
  };

  describe "HTFeed::Storage::VersionedPairtree" => sub {
    use HTFeed::Storage::VersionedPairtree;

    sub storage_instance {
      my $stage = setup_stage(@_);
      my $volume = $stage->{volume};

      my $storage = HTFeed::Storage::VersionedPairtree->new(
        volume => $volume,
        collate => $stage);

      return $storage;
    }

    sub collate_with_storage {
      my $storage = shift;

      $storage->stage;
      $storage->validate;
      $storage->make_object_path;
      $storage->move;
    }

    describe "#object_path" => sub {

      it "uses config for object root" => sub {
        my $old_storage = get_config('repository','backup_obj_dir');
        set_config('/backup-location/obj','repository','backup_obj_dir');

        eval {
          my $storage = storage_instance($tmpdirs, 'test', 'test');
          like( $storage->object_path(), qr{^/backup-location/obj/});
        };

        set_config($old_storage, 'repository','backup_obj_dir');
      };

      it "includes the namespace and pairtreeized object id in the path" => sub {
        my $storage = storage_instance($tmpdirs, 'test', 'test');

        like( $storage->object_path(), qr{/test/pairtree_root/te/st/test});
      };

      it "includes a datestamp in the object directory" => sub {
        my $storage = storage_instance($tmpdirs,'test','test');

        like( $storage->object_path(), qr{/test/\d{14}});
      };
    };

    describe "#stage" => sub {
      it "deposits to a staging area under the configured object location" => sub {
        my $storage = storage_instance($tmpdirs, 'test', 'test');
        $storage->stage;

        ok(-e "$tmpdirs->{backup_obj_stage_dir}/test.test/test.mets.xml");
        ok(-e "$tmpdirs->{backup_obj_stage_dir}/test.test/test.zip");
      }
    };

    describe "#validate" => sub {
      it "returns false and logs for a corrupted zip" => sub {
        my $storage = storage_instance($tmpdirs, 'test', 'bad_zip');
        $storage->stage;

        eval { not_ok($storage->validate); };
        ok($testlog->matches(qr(ERROR.*Checksum.*bad_zip.zip)));
      };

      it "returns true for a zip matching the checksum in the METS" => sub {
        my $storage = storage_instance($tmpdirs, 'test', 'test');
        $storage->stage;

        ok($storage->validate);
      }
    };

    describe "#make_object_path" => sub {
      it "makes the path with a timestamp" => sub {
        my $storage = storage_instance($tmpdirs, 'test','test');

        $storage->make_object_path;

        ok(-d "$tmpdirs->{backup_obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}");
      }
    };

    describe "#move" => sub {
      it "moves from the staging location to the object path" => sub {
        my $storage = storage_instance($tmpdirs,'test','test');
        collate_with_storage($storage);

        ok(! -e "$tmpdirs->{backup_obj_stage_dir}/test.test","cleans up the staging dir");
        ok(-e "$tmpdirs->{backup_obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}/test.zip","copies the zip");
        ok(-e "$tmpdirs->{backup_obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}/test.mets.xml","copies the mets");
      };

      it "records the copy in the feed_backups table" => sub {
        my $dbh = get_dbh();

        $dbh->do("DELETE FROM feed_backups WHERE namespace = 'test' and id = 'test'");

        my $storage = storage_instance($tmpdirs,'test','test');
        collate_with_storage($storage);

        my $r = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

        is($r->[0][0],$storage->{timestamp});

      };
    };

    describe "#record_backup" => sub {
      it "does not record anything in feed_backups if the volume wasn't moved" => sub {
        my $dbh = get_dbh();

        $dbh->do("DELETE FROM feed_backups WHERE namespace = 'test' and id = 'test'");

        my $storage = storage_instance($tmpdirs,'test','test');
        $storage->stage;

        eval { $storage->record_backup };

        my $r = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

        is(scalar(@$r),0);

      };
    }
  };
};

runtests unless caller;
