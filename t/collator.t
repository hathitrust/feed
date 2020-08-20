use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(stage_volume);
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);


describe "HTFeed::Collator" => sub {
  local our $tmpdirs;
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


  sub make_old_version {
    my $collator = shift;

    $collator->make_object_path;

    open(my $zip_fh, ">", $collator->zip_obj_path);
    print $zip_fh "old version\n";
    $zip_fh->close;

    open(my $mets_fh,">",$collator->mets_obj_path);
    print $mets_fh "old version\n";
    $mets_fh->close;
  }

  describe "HTFeed::Collator::LinkedPairtree" => sub {
    use HTFeed::Collator::LinkedPairtree;

    sub make_old_version_other_dir {
      my $volume = stage_volume($tmpdirs,@_);

      my $collator = HTFeed::Collator::LinkedPairtree->new(
        volume => $volume,
        config => {
          obj_dir => $tmpdirs->{other_obj_dir},
          link_dir => $tmpdirs->{link_dir}
        }
      );

      make_old_version($collator);
    }

    sub linked_collator {
      my $volume = stage_volume($tmpdirs,@_);

      my $collator = HTFeed::Collator::LinkedPairtree->new(
        volume => $volume,
        config => {
          obj_dir => $tmpdirs->{obj_dir},
          link_dir => $tmpdirs->{link_dir}
        }
      );

      return $collator;
    }

    it "moves the existing version aside when the link target doesn't match current objdir" => sub {
      make_old_version_other_dir('test','test');
      my $collator = linked_collator( 'test', 'test');
      $collator->stage;
      $collator->make_object_path;
      $collator->move;

      ok(-e "$tmpdirs->{other_obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
      ok(-e "$tmpdirs->{other_obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

    };

    describe "#make_object_path" => sub {

      context "when the object is not in the repo" => sub {
        it "creates a symlink for the volume" => sub {
          my $collator = linked_collator('test','test');
          $collator->make_object_path;

          is("$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test",
            readlink("$tmpdirs->{link_dir}/test/pairtree_root/te/st/test"));
        };

        it "does not set is_repeat if the object is not in the repo" => sub {
          my $collator = linked_collator('test','test');
          $collator->make_object_path;

          ok(!$collator->{is_repeat});
        }
      };

      context "when the object is in the repo with link target matching obj_dir" => sub {
        it "sets is_repeat" => sub {
          make_old_version(linked_collator('test','test'));

          my $collator = linked_collator('test','test');
          $collator->make_object_path;

          ok($collator->{is_repeat});
        };
      };

      context "when the object is in the repo but link target doesn't match current obj dir" => sub {
        it "uses existing target of the link" => sub {
          make_old_version_other_dir('test','test');

          my $collator = linked_collator('test','test');
          $collator->make_object_path;

          is($collator->object_path,"$tmpdirs->{other_obj_dir}/test/pairtree_root/te/st/test");
        };

        it "sets is_repeat" => sub {
          make_old_version_other_dir('test','test');

          my $collator = linked_collator('test','test');
          $collator->make_object_path;

          ok($collator->{is_repeat});
        }
      };
    };

    describe "#stage" => sub {
      context "when the item is in the repository with a different collator path" => sub {
        it "deposits to a staging area under that path" => sub {
          make_old_version_other_dir('test','test');
          my $collator = linked_collator( 'test', 'test');
          $collator->stage;

          ok(-e "$tmpdirs->{other_obj_dir}/.tmp/test.test/test.mets.xml");
          ok(-e "$tmpdirs->{other_obj_dir}/.tmp/test.test/test.zip");
        };
      };
    };
  };

  describe "HTFeed::Collator::LocalPairtree" => sub {
    use HTFeed::Collator::LocalPairtree;

    sub local_collator {
      my $volume = stage_volume($tmpdirs,@_);

      my $collator = HTFeed::Collator::LocalPairtree->new(
        volume => $volume,
        config => {
          obj_dir => $tmpdirs->{obj_dir},
        }
      );

      return $collator;
    }

    describe "#move" => sub {
      it "copies the mets and zip to the repository" => sub {
        my $collator = local_collator( 'test', 'test');
        $collator->stage;
        $collator->make_object_path;
        $collator->move;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip");
      };

      it "moves the existing version aside" => sub {
        make_old_version(local_collator('test','test'));
        my $collator = local_collator( 'test', 'test');

        $collator->stage;
        $collator->make_object_path;
        $collator->move;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

      };
    };

    describe "#make_object_path" => sub {

      context "when the object is not in the repo" => sub {
        it "does not set is_repeat if the object is not in the repo" => sub {
          my $collator = local_collator('test','test');
          $collator->make_object_path;

          ok(!$collator->{is_repeat});
        }
      };

      it "works" => sub {
        my $collator = local_collator('test','test');
        $collator->make_object_path;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test");
      };

      it "is idempotent" => sub {
        my $collator = local_collator('test','test');
        $collator->make_object_path;
        $collator->make_object_path;

        ok(! @{$collator->{errors}});
      };
    };

    describe "#zipvalidate" => sub {
      context "with a zip whose contents do not match the METS" => sub {
        it "returns false" => sub {
          my $collator = local_collator('test','bad_file_checksum');
          ok(!$collator->zipvalidate);
        };

        it "logs an error about the file" => sub {
          my $collator = local_collator('test','bad_file_checksum');
          $collator->zipvalidate;

          ok($testlog->matches(qr(ERROR.*Checksum.*00000001.jp2)));
        };
      };

      it "with a zip whose contents match the METS returns true" => sub {
        my $collator = local_collator('test','test');
        $collator->stage;
        ok($collator->zipvalidate);
      };
    };

    describe "#prevalidate" => sub {

      context "with a zip whose checksum does not match the one in the METS" => sub {
        it "returns false" => sub {
          my $collator = local_collator('test','bad_zip');
          $collator->stage;

          ok(!$collator->prevalidate);
        };

        it "logs an error about the zip" => sub {
          my $collator = local_collator('test','bad_zip');
          $collator->stage;
          $collator->prevalidate;

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
          my $collator = local_collator('test','test');
          $collator->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$collator->mets_stage_path);

          ok(!$collator->prevalidate);
        };

        it "logs an error" => sub {
          my $collator = local_collator('test','test');
          $collator->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$collator->mets_stage_path);

          # put a bad METS in staging
          $collator->prevalidate;
          ok($testlog->matches(qr(ERROR.*Checksum.*mets.xml)));
        };
      };

      it "with a zip whose checksum matches the METS returns true" => sub {
        my $collator = local_collator('test','test');
        $collator->stage;
        ok($collator->prevalidate);
      };
    };

    describe "#postvalidate" => sub {
      context "with a zip whose checksum does not match the one in the METS" => sub {
        it "fails for a zip whose checksum does not match the one in the METS" => sub {
          my $collator = local_collator('test','bad_zip');
          $collator->stage;
          $collator->make_object_path;
          $collator->move;

          ok(!$collator->postvalidate);
        };

        it "logs an error" => sub {
          my $collator = local_collator('test','bad_zip');
          $collator->stage;
          $collator->make_object_path;
          $collator->move;
          $collator->postvalidate;

          ok($testlog->matches(qr(ERROR.*Checksum.*bad_zip.zip)));
        };
      };

      context "with a METS that does not match the original METS" => sub {
        it "returns false" => sub {
          my $collator = local_collator('test','test');
          $collator->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$collator->mets_stage_path);
          $collator->make_object_path;
          $collator->move;

          ok(!$collator->postvalidate);
        };

        it "logs an error" => sub {
          my $collator = local_collator('test','test');
          $collator->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$collator->mets_stage_path);
          $collator->make_object_path;
          $collator->move;
          $collator->postvalidate;

          ok($testlog->matches(qr(ERROR.*Checksum.*mets.xml)));
        };
      };

      it "succeeds for a zip whose checksum matches the METS" => sub {
        my $collator = local_collator('test','test');
        $collator->stage;
        $collator->make_object_path;
        $collator->move;

        ok($collator->postvalidate);
      };

    };

    describe "#rollback" => sub {
      it "restores the original version" => sub {
        make_old_version(local_collator('test','test'));
        my $collator = local_collator( 'test', 'test');

        $collator->stage;
        $collator->make_object_path;
        $collator->move;
        $collator->rollback;

        ok(! -e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
        ok(! -e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

        my ($fh, $contents);

        open($fh, "<", "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml");
        $contents = <$fh>;
        is($contents,"old version\n","restores the old mets");

        open($fh, "<", "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip");
        $contents = <$fh>;
        is($contents,"old version\n","restores the old zip");

      };
    };

    it "leaves the .old version there if it didn't put it there" => sub {
      make_old_version(local_collator('test','test'));
      my $oldzip = "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip.old";
      open(my $fh, ">", $oldzip);
      print $fh "leftover junk\n";

      my $collator = local_collator( 'test', 'test');

      $collator->stage;
      $collator->rollback;

      ok(-e $oldzip);

    };

    describe "#record_audit" => sub {
      it "records an md5 check in the feed_audit table" => sub {
        my $dbh = get_dbh();

        my $collator = local_collator('test','test');
        $collator->stage;
        $collator->make_object_path;
        $collator->move;
        $collator->record_audit;

        my $r = $dbh->selectall_arrayref("SELECT lastmd5check from feed_audit WHERE namespace = 'test' and id = 'test'");

        ok($r->[0][0]);

      };
    };

		describe "#stage" => sub {
      context "when the item is not in repository" => sub {
        it "stages to the configured staging location" => sub {
          my $collator = local_collator( 'test', 'test');
          $collator->stage;

          ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.mets.xml");
          ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.zip");
        };
      };
		};

    describe "#cleanup" => sub {
      it "removes the moved-aside old version" => sub {
        make_old_version(local_collator('test','test'));
        my $collator = local_collator( 'test', 'test');

        $collator->stage;
        $collator->make_object_path;
        $collator->move;
        $collator->cleanup;

        ok(! -e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
        ok(! -e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

      }
    };

    describe "#clean_staging" => sub {
      it "removes anything in the temporary staging area" => sub {
        my $collator = local_collator( 'test', 'test');

        $collator->stage;
        $collator->clean_staging;

        ok(! -e "$tmpdirs->{obj_dir}/.tmp/test.test");
      };
    };


  };

  describe "HTFeed::Collator::VersionedPairtree" => sub {
    use HTFeed::Collator::VersionedPairtree;

    sub versioned_collator {
      my $volume = stage_volume($tmpdirs,@_);

      my $collator = HTFeed::Collator::VersionedPairtree->new(
        volume => $volume,
        config => {
          obj_dir => $tmpdirs->{obj_dir},
        }
      );

      return $collator;
    }

    describe "#object_path" => sub {

      it "uses config for object root" => sub {
        eval {
          my $collator = versioned_collator('test', 'test');
          $collator->set_collator_config('/backup-location/obj','obj_dir');
          like( $collator->object_path(), qr{^/backup-location/obj/});
        };
      };

      it "includes the namespace and pairtreeized object id in the path" => sub {
        my $collator = versioned_collator('test', 'test');

        like( $collator->object_path(), qr{/test/pairtree_root/te/st/test});
      };

      it "includes a datestamp in the object directory" => sub {
        my $collator = versioned_collator('test','test');

        like( $collator->object_path(), qr{/test/\d{14}});
      };
    };

    describe "#stage" => sub {
      it "deposits to a staging area under the configured object location" => sub {
        my $collator = versioned_collator('test', 'test');
        $collator->stage;

        ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.mets.xml");
        ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.zip");
      }
    };

    describe "#make_object_path" => sub {
      it "makes the path with a timestamp" => sub {
        my $collator = versioned_collator('test','test');

        $collator->make_object_path;

        ok(-d "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$collator->{timestamp}");
      }
    };

    describe "#move" => sub {
      it "moves from the staging location to the object path" => sub {
        my $collator = versioned_collator('test','test');
        $collator->stage;
        $collator->make_object_path;
        $collator->move;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$collator->{timestamp}/test.zip","copies the zip");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$collator->{timestamp}/test.mets.xml","copies the mets");
      };
    };

    describe "#record_backup" => sub {
      it "records the copy in the feed_backups table" => sub {
        my $collator = versioned_collator('test','test');
        $collator->stage;
        $collator->make_object_path;
        $collator->move;
        $collator->record_backup;

        my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

        is($r->[0][0],$collator->{timestamp});
      };

      it "does not record anything in feed_backups if the volume wasn't moved" => sub {

        my $collator = versioned_collator('test','test');
        $collator->stage;

        eval { $collator->record_backup };

        my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

        is(scalar(@$r),0);

      };
    }
  };
};

runtests unless caller;
