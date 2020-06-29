use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(stage_volume);
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);

describe "HTFeed::Storage" => sub {
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

  describe "HTFeed::Storage::LocalPairtree" => sub {
    use HTFeed::Storage::LocalPairtree;

    sub local_storage {
      my $volume = stage_volume(@_);

      my $storage = HTFeed::Storage::LocalPairtree->new(
        volume => $volume);

      return $storage;
    }

    sub make_old_version_other_dir {
      my $storage = shift;

      my $real_obj_dir = get_config('repository','obj_dir');
      my $other_obj_dir = get_config('repository','other_obj_dir');
      set_config($other_obj_dir,'repository','obj_dir');

      make_old_version($storage);

      set_config($real_obj_dir,'repository','obj_dir');
    }

    sub make_old_version {
      my $storage = shift;

      $storage->make_object_path;

      open(my $zip_fh, ">", $storage->zip_obj_path);
      print $zip_fh "old version\n";
      $zip_fh->close;

      open(my $mets_fh,">",$storage->mets_obj_path);
      print $mets_fh "old version\n";
      $mets_fh->close;
    }

    describe "#move" => sub {
      it "copies the mets and zip to the repository" => sub {
        my $storage = local_storage($tmpdirs, 'test', 'test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip");
      };

      it "moves the existing version aside" => sub {
        make_old_version(local_storage($tmpdirs,'test','test'));
        my $storage = local_storage($tmpdirs, 'test', 'test');

        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

      };

      it "moves the existing version aside when the link target doesn't match current objdir" => sub {
        make_old_version_other_dir(local_storage($tmpdirs, 'test','test'));
        my $storage = local_storage($tmpdirs, 'test', 'test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok(-e "$tmpdirs->{other_obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
        ok(-e "$tmpdirs->{other_obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

      };
    };

    describe "#make_object_path" => sub {

      context "when the object is not in the repo" => sub {
        it "creates a symlink for the volume" => sub {
          my $storage = local_storage($tmpdirs,'test','test');
          $storage->make_object_path;

          is("$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test",
            readlink("$tmpdirs->{link_dir}/test/pairtree_root/te/st/test"));
        };

        it "does not set is_repeat if the object is not in the repo" => sub {
          my $storage = local_storage($tmpdirs,'test','test');
          $storage->make_object_path;

          ok(!$storage->{is_repeat});
        }
      };


      context "when the object is in the repo with link target matching obj_dir" => sub {
        it "sets is_repeat" => sub {
          make_old_version(local_storage($tmpdirs,'test','test'));

          my $storage = local_storage($tmpdirs,'test','test');
          $storage->make_object_path;

          ok($storage->{is_repeat});
        };
      };

      context "when the object is in the repo but link target doesn't match current obj dir" => sub {
        it "uses existing target of the link" => sub {
          make_old_version_other_dir(local_storage($tmpdirs,'test','test'));

          my $storage = local_storage($tmpdirs,'test','test');
          $storage->make_object_path;

          is($storage->object_path,"$tmpdirs->{other_obj_dir}/test/pairtree_root/te/st/test");
        };

        it "sets is_repeat" => sub {
          make_old_version_other_dir(local_storage($tmpdirs,'test','test'));

          my $storage = local_storage($tmpdirs,'test','test');
          $storage->make_object_path;

          ok($storage->{is_repeat});
        }
      };
    };

    describe "#prevalidate" => sub {

      context "with a zip whose checksum does not match the one in the METS" => sub {
        it "returns false" => sub {
          my $storage = local_storage($tmpdirs,'test','bad_zip');
          $storage->stage;

          ok(!$storage->prevalidate);
        };

        it "logs an error about the zip" => sub {
          my $storage = local_storage($tmpdirs,'test','bad_zip');
          $storage->stage;
          $storage->prevalidate;

          ok($testlog->matches(qr(ERROR.*Checksum.*bad_zip.zip)));
        };
      };

      context "with a METS that does not match the original METS" => sub {
        # Note: prevalidate would catch most kinds of errors with corrupted
        # METS by either being unable to parse the METS or because the manifest
        # would not match the zip. This METS has been corrupted in such a way that
        # it forces us to compare the METS to the orginal volume METS to detect
        # the problem -- the manifest and checksums are intact, but other
        # attributes have been changed.

        it "returns false" => sub {
          my $storage = local_storage($tmpdirs,'test','test');
          $storage->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$storage->mets_stage_path);

          ok(!$storage->prevalidate);
        };

        it "logs an error" => sub {
          my $storage = local_storage($tmpdirs,'test','test');
          $storage->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$storage->mets_stage_path);

          # put a bad METS in staging
          $storage->prevalidate;
          ok($testlog->matches(qr(ERROR.*Checksum.*mets.xml)));
        };
      };

      context "with a zip whose contents do not match the METS" => sub {
        it "returns false" => sub {
          my $storage = local_storage($tmpdirs,'test','bad_file_checksum');
          $storage->stage;
          ok(!$storage->prevalidate);
        };

        it "logs an error about the file" => sub {
          my $storage = local_storage($tmpdirs,'test','bad_file_checksum');
          $storage->stage;
          $storage->prevalidate;

          ok($testlog->matches(qr(ERROR.*Checksum.*00000001.jp2)));
        };
      };

      it "with a zip whose checksum and contents match the METS returns true" => sub {
        my $storage = local_storage($tmpdirs,'test','test');
        $storage->stage;
        ok($storage->prevalidate);
      };
    };

    describe "#postvalidate" => sub {
      context "with a zip whose checksum does not match the one in the METS" => sub {
        it "fails for a zip whose checksum does not match the one in the METS" => sub {
          my $storage = local_storage($tmpdirs,'test','bad_zip');
          $storage->stage;
          $storage->make_object_path;
          $storage->move;

          ok(!$storage->postvalidate);
        };

        it "logs an error" => sub {
          my $storage = local_storage($tmpdirs,'test','bad_zip');
          $storage->stage;
          $storage->make_object_path;
          $storage->move;
          $storage->postvalidate;

          ok($testlog->matches(qr(ERROR.*Checksum.*bad_zip.zip)));
        };
      };

      context "with a METS that does not match the original METS" => sub {
        it "returns false" => sub {
          my $storage = local_storage($tmpdirs,'test','test');
          $storage->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$storage->mets_stage_path);
          $storage->make_object_path;
          $storage->move;

          ok(!$storage->postvalidate);
        };

        it "logs an error" => sub {
          my $storage = local_storage($tmpdirs,'test','test');
          $storage->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$storage->mets_stage_path);
          $storage->make_object_path;
          $storage->move;
          $storage->postvalidate;

          ok($testlog->matches(qr(ERROR.*Checksum.*mets.xml)));
        };
      };

      it "succeeds for a zip whose checksum matches the METS" => sub {
        my $storage = local_storage($tmpdirs,'test','test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok($storage->postvalidate);
      };

    };

    describe "#rollback" => sub {
      it "restores the original version" => sub {
        my $storage = local_storage($tmpdirs,'test','test');
        make_old_version($storage);
      };
    };

    describe "#record_audit" => sub {
      it "records an md5 check in the feed_audit table" => sub {
        my $dbh = get_dbh();

        my $storage = local_storage($tmpdirs,'test','test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->record_audit;

        my $r = $dbh->selectall_arrayref("SELECT lastmd5check from feed_audit WHERE namespace = 'test' and id = 'test'");

        ok($r->[0][0]);

      };
    };

    describe "#cleanup" => sub {
      it "removes the moved-aside old version" => sub {
        make_old_version(local_storage($tmpdirs,'test','test'));
        my $storage = local_storage($tmpdirs, 'test', 'test');

        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->cleanup;

        ok(! -e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
        ok(! -e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

      }
    };

  };

  describe "HTFeed::Storage::VersionedPairtree" => sub {
    use HTFeed::Storage::VersionedPairtree;

    sub versioned_storage {
      my $volume = stage_volume(@_);

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
      };
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
