use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use Test::Exception;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(stage_volume);
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);

use strict;

describe "HTFeed::Storage" => sub {
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
    my $storage = shift;

    $storage->make_object_path;

    open(my $zip_fh, ">", $storage->zip_obj_path);
    print $zip_fh "old version\n";
    $zip_fh->close;

    open(my $mets_fh,">",$storage->mets_obj_path);
    print $mets_fh "old version\n";
    $mets_fh->close;
  }

  describe "HTFeed::Storage::LinkedPairtree" => sub {
    use HTFeed::Storage::LinkedPairtree;

    sub make_old_version_other_dir {
      my $volume = stage_volume($tmpdirs,@_);

      my $storage = HTFeed::Storage::LinkedPairtree->new(
        volume => $volume,
        config => {
          obj_dir => $tmpdirs->{other_obj_dir},
          link_dir => $tmpdirs->{link_dir}
        }
      );

      make_old_version($storage);
    }

    sub linked_storage {
      my $volume = stage_volume($tmpdirs,@_);

      my $storage = HTFeed::Storage::LinkedPairtree->new(
        volume => $volume,
        config => {
          obj_dir => $tmpdirs->{obj_dir},
          link_dir => $tmpdirs->{link_dir}
        }
      );

      return $storage;
    }

    it "moves the existing version aside when the link target doesn't match current objdir" => sub {
      make_old_version_other_dir('test','test');
      my $storage = linked_storage( 'test', 'test');
      $storage->stage;
      $storage->make_object_path;
      $storage->move;

      ok(-e "$tmpdirs->{other_obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
      ok(-e "$tmpdirs->{other_obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

    };

    describe "#make_object_path" => sub {

      context "when the object is not in the repo" => sub {
        it "creates a symlink for the volume" => sub {
          my $storage = linked_storage('test','test');
          $storage->make_object_path;

          is("$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test",
            readlink("$tmpdirs->{link_dir}/test/pairtree_root/te/st/test"));
        };

        it "does not set is_repeat if the object is not in the repo" => sub {
          my $storage = linked_storage('test','test');
          $storage->make_object_path;

          ok(!$storage->{is_repeat});
        }
      };

      context "when the object is in the repo with link target matching obj_dir" => sub {
        it "sets is_repeat" => sub {
          make_old_version(linked_storage('test','test'));

          my $storage = linked_storage('test','test');
          $storage->make_object_path;

          ok($storage->{is_repeat});
        };
      };

      context "when the object is in the repo but link target doesn't match current obj dir" => sub {
        it "uses existing target of the link" => sub {
          make_old_version_other_dir('test','test');

          my $storage = linked_storage('test','test');
          $storage->make_object_path;

          is($storage->object_path,"$tmpdirs->{other_obj_dir}/test/pairtree_root/te/st/test");
        };

        it "sets is_repeat" => sub {
          make_old_version_other_dir('test','test');

          my $storage = linked_storage('test','test');
          $storage->make_object_path;

          ok($storage->{is_repeat});
        }
      };
    };

    describe "#stage" => sub {
      context "when the item is in the repository with a different storage path" => sub {
        it "deposits to a staging area under that path" => sub {
          make_old_version_other_dir('test','test');
          my $storage = linked_storage( 'test', 'test');
          $storage->stage;

          ok(-e "$tmpdirs->{other_obj_dir}/.tmp/test.test/test.mets.xml");
          ok(-e "$tmpdirs->{other_obj_dir}/.tmp/test.test/test.zip");
        };
      };
    };
  };

  describe "HTFeed::Storage::LocalPairtree" => sub {
    use HTFeed::Storage::LocalPairtree;

    sub local_storage {
      my $volume = stage_volume($tmpdirs,@_);

      my $storage = HTFeed::Storage::LocalPairtree->new(
        volume => $volume,
        config => {
          obj_dir => $tmpdirs->{obj_dir},
        }
      );

      return $storage;
    }

    describe "#move" => sub {
      it "copies the mets and zip to the repository" => sub {
        my $storage = local_storage( 'test', 'test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip");
      };

      it "moves the existing version aside" => sub {
        make_old_version(local_storage('test','test'));
        my $storage = local_storage( 'test', 'test');

        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

      };
    };

    describe "#make_object_path" => sub {

      context "when the object is not in the repo" => sub {
        it "does not set is_repeat if the object is not in the repo" => sub {
          my $storage = local_storage('test','test');
          $storage->make_object_path;

          ok(!$storage->{is_repeat});
        }
      };

      it "works" => sub {
        my $storage = local_storage('test','test');
        $storage->make_object_path;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test");
      };

      it "is idempotent" => sub {
        my $storage = local_storage('test','test');
        $storage->make_object_path;
        $storage->make_object_path;

        ok(! @{$storage->{errors}});
      };
    };

    describe "#validate_zip_completeness" => sub {
      context "with a zip whose contents do not match the METS" => sub {
        it "returns false" => sub {
          my $storage = local_storage('test','bad_file_checksum');
          ok(!$storage->validate_zip_completeness);
        };

        it "logs an error about the file" => sub {
          my $storage = local_storage('test','bad_file_checksum');
          $storage->validate_zip_completeness;

          ok($testlog->matches(qr(ERROR.*Checksum.*00000001.jp2)));
        };
      };

      it "with a zip whose contents match the METS returns true" => sub {
        my $storage = local_storage('test','test');
        $storage->stage;
        ok($storage->validate_zip_completeness);
      };
    };

    describe "#prevalidate" => sub {

      context "with a zip whose checksum does not match the one in the METS" => sub {
        it "returns false" => sub {
          my $storage = local_storage('test','bad_zip');
          $storage->stage;

          ok(!$storage->prevalidate);
        };

        it "logs an error about the zip" => sub {
          my $storage = local_storage('test','bad_zip');
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
          my $storage = local_storage('test','test');
          $storage->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$storage->mets_stage_path);

          ok(!$storage->prevalidate);
        };

        it "logs an error" => sub {
          my $storage = local_storage('test','test');
          $storage->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$storage->mets_stage_path);

          # put a bad METS in staging
          $storage->prevalidate;
          ok($testlog->matches(qr(ERROR.*Checksum.*mets.xml)));
        };
      };

      it "with a zip whose checksum matches the METS returns true" => sub {
        my $storage = local_storage('test','test');
        $storage->stage;
        ok($storage->prevalidate);
      };
    };

    describe "#postvalidate" => sub {
      context "with a zip whose checksum does not match the one in the METS" => sub {
        it "fails for a zip whose checksum does not match the one in the METS" => sub {
          my $storage = local_storage('test','bad_zip');
          $storage->stage;
          $storage->make_object_path;
          $storage->move;

          ok(!$storage->postvalidate);
        };

        it "logs an error" => sub {
          my $storage = local_storage('test','bad_zip');
          $storage->stage;
          $storage->make_object_path;
          $storage->move;
          $storage->postvalidate;

          ok($testlog->matches(qr(ERROR.*Checksum.*bad_zip.zip)));
        };
      };

      context "with a METS that does not match the original METS" => sub {
        it "returns false" => sub {
          my $storage = local_storage('test','test');
          $storage->stage;
          # validate zip should pass but METS doesn't match volume METS
          my $other_mets = get_config('staging','fetch') . "/test.mets.xml-corrupted";
          system("cp",$other_mets,$storage->mets_stage_path);
          $storage->make_object_path;
          $storage->move;

          ok(!$storage->postvalidate);
        };

        it "logs an error" => sub {
          my $storage = local_storage('test','test');
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
        my $storage = local_storage('test','test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok($storage->postvalidate);
      };

    };

    describe "#rollback" => sub {
      it "restores the original version" => sub {
        make_old_version(local_storage('test','test'));
        my $storage = local_storage( 'test', 'test');

        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->rollback;

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
      make_old_version(local_storage('test','test'));
      my $oldzip = "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip.old";
      open(my $fh, ">", $oldzip);
      print $fh "leftover junk\n";

      my $storage = local_storage( 'test', 'test');

      $storage->stage;
      $storage->rollback;

      ok(-e $oldzip);

    };

    describe "#record_audit" => sub {
      it "records an md5 check in the feed_audit table" => sub {
        my $dbh = get_dbh();

        my $storage = local_storage('test','test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->record_audit;

        my $r = $dbh->selectall_arrayref("SELECT lastmd5check from feed_audit WHERE namespace = 'test' and id = 'test'");

        ok($r->[0][0]);

      };
    };

		describe "#stage" => sub {
      context "when the item is not in repository" => sub {
        it "stages to the configured staging location" => sub {
          my $storage = local_storage( 'test', 'test');
          $storage->stage;

          ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.mets.xml");
          ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.zip");
        };
      };
		};

    describe "#cleanup" => sub {
      it "removes the moved-aside old version" => sub {
        make_old_version(local_storage('test','test'));
        my $storage = local_storage( 'test', 'test');

        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->cleanup;

        ok(! -e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml.old");
        ok(! -e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip.old");

      }
    };

    describe "#clean_staging" => sub {
      it "removes anything in the temporary staging area" => sub {
        my $storage = local_storage( 'test', 'test');

        $storage->stage;
        $storage->clean_staging;

        ok(! -e "$tmpdirs->{obj_dir}/.tmp/test.test");
      };
    };

  };

  describe "HTFeed::Storage::ObjectStore" => sub {
    use HTFeed::Storage::ObjectStore;
    use HTFeed::Storage::S3;

    local our $bucket;
    local our $s3;

    before all => sub {
      $bucket = "bucket" . sprintf("%08d",rand(1000000));
      $s3 = HTFeed::Storage::S3->new(
        bucket => $bucket,
        awscli => ['aws','--endpoint-url','http://minio:9000']
      );

      $s3->mb;
    };

    after all => sub {
      $s3->rm('/',"--recursive");
      $s3->rb;
    };

    sub object_storage {
      my $volume = stage_volume($tmpdirs,@_);

      my $storage = HTFeed::Storage::ObjectStore->new(
        volume => $volume,
        config => {
          bucket => $s3->{bucket},
          awscli => $s3->{awscli}
        },
      );

      return $storage;
    }

    describe "#object_path" => sub {
      it "includes the namespace, pairtreeized object id, and datestamp" => sub {
        my $storage = object_storage('test','ark:/123456/abcde');

        like($storage->object_path, qr/^test\.ark\+=123456=abcde\.\d{14}$/);
      };
    };

    describe "#stage" => sub {
      it "returns true" => sub {
        my $storage = object_storage('test','test');
        ok( $storage->stage );
      }
    };

    describe "#prevalidate" => sub {
      it "returns true" => sub {
        my $storage = object_storage('test','test');
        ok( $storage->prevalidate );
      };
    };

    describe "#stage_path" => sub {
      it "raises an exception" => sub {
        my $storage = object_storage('test','test');
        dies_ok { $storage->stage_path } "doesn't implement stage_path"
      }
    };

    describe "#move" => sub {
      before each => sub {
        $s3->rm("/","--recursive");
      };

      it "uploads zip and mets" => sub {
        my $storage = object_storage('test','test');
        $storage->move;

        ok($s3->s3_has("test.test.$storage->{timestamp}.zip"));
        ok($s3->s3_has("test.test.$storage->{timestamp}.mets.xml"));
      };

      it "includes checksum in object metadata" => sub {
        my $storage = object_storage('test','test');
        $storage->move;

        #  s3api('head-object',
        # aws s3api head-object --bucket test --key test.test.$storage->{timestamp}.zip
        # then get Metadata -> "content-md5", base64 decode & hex encode
      };

      # basically we want to test that we're properly using the checksum verification
      it "returns false if upload file doesn't match expected checksum";
      # other checks for if upload doesn't complete successfully?
    };

    describe "#make_object_path" => sub {
      it "returns true" => sub {
        my $storage = object_storage('test','test');
        ok( $storage->make_object_path );
      };
    };

    describe "#postvalidate" => sub {
      it "returns false if zip is not in s3";
      it "returns false if mets is not in s3";
      it "returns false if zip does not have correct checksum metadata";
      it "returns false if mets does not have correct checksum metadata";
    };

    describe "#record_audit" => sub {
      it "records the backup";
      it "records the checksum of the encrypted zip";
    };
  };

  describe "HTFeed::Storage::VersionedPairtree" => sub {
    use HTFeed::Storage::VersionedPairtree;

    sub versioned_storage {
      my $volume = stage_volume($tmpdirs,@_);

      my $storage = HTFeed::Storage::VersionedPairtree->new(
        volume => $volume,
        config => {
          obj_dir => $tmpdirs->{obj_dir},
        }
      );

      return $storage;
    }

    describe "#object_path" => sub {

      it "uses config for object root" => sub {
        eval {
          my $storage = versioned_storage('test', 'test');
          $storage->set_storage_config('/backup-location/obj','obj_dir');
          like( $storage->object_path(), qr{^/backup-location/obj/});
        };
      };

      it "includes the namespace and pairtreeized object id in the path" => sub {
        my $storage = versioned_storage('test', 'test');

        like( $storage->object_path(), qr{/test/pairtree_root/te/st/test});
      };

      it "includes a datestamp in the object directory" => sub {
        my $storage = versioned_storage('test','test');

        like( $storage->object_path(), qr{/test/\d{14}});
      };
    };

    describe "#stage" => sub {
      it "deposits to a staging area under the configured object location" => sub {
        my $storage = versioned_storage('test', 'test');
        $storage->stage;

        ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.mets.xml");
        ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.zip");
      }
    };

    describe "#make_object_path" => sub {
      it "makes the path with a timestamp" => sub {
        my $storage = versioned_storage('test','test');

        $storage->make_object_path;

        ok(-d "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}");
      }
    };

    describe "#move" => sub {
      it "moves from the staging location to the object path" => sub {
        my $storage = versioned_storage('test','test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}/test.zip","copies the zip");
        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}/test.mets.xml","copies the mets");
      };
    };

    describe "#record_backup" => sub {
      it "records the copy in the feed_backups table" => sub {
        my $storage = versioned_storage('test','test');
        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->record_backup;

        my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

        is($r->[0][0],$storage->{timestamp});
      };

      it "does not record anything in feed_backups if the volume wasn't moved" => sub {

        my $storage = versioned_storage('test','test');
        $storage->stage;

        eval { $storage->record_backup };

        my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

        is(scalar(@$r),0);

      };
    };

    context "with encryption enabled" => sub {
      sub encrypted_storage {
        my $volume = stage_volume($tmpdirs,@_);

        my $storage = HTFeed::Storage::VersionedPairtree->new(
          volume => $volume,
          config => {
            obj_dir => $tmpdirs->{obj_dir},
            encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
          },
        );

        return $storage;
      }
      # enable encryption..

      it "stages only the encrypted zip" => sub {
        my $storage = encrypted_storage('test', 'test');
        $storage->encrypt;
        $storage->stage;

        ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.zip.gpg", "copies the encrypted zip");
        ok(!-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.zip", "does not copy the unencrypted zip");
      };

      it "puts only the encrypted zip in object storage" => sub {
        my $storage = encrypted_storage('test', 'test');
        $storage->encrypt;
        $storage->stage;
        $storage->make_object_path;
        $storage->move;

        ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}/test.zip.gpg","copies the encrypted zip");
        ok(! -e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/$storage->{timestamp}/test.zip","does not copy the unencrypted zip");
      };

      it "records the checksum of the encrypted zip" => sub {
        my $storage = encrypted_storage('test', 'test');

        $storage->encrypt;
        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        $storage->record_audit;

        my $r = get_dbh()->selectall_arrayref("SELECT saved_md5sum from feed_backups WHERE namespace = 'test' and id = 'test'");
        my $crypted = $storage->zip_source();
        ok($crypted =~ /\.gpg$/);
        my $checksum = `md5sum $crypted | cut -f 1 -d ' '`;
        chomp $checksum;
        is($r->[0][0],$checksum);
      };

      it "succeeds at pre-validation" => sub {
        my $storage = encrypted_storage('test', 'test');

        $storage->encrypt;
        $storage->stage;
        ok($storage->prevalidate);
      };

      it "succeeds at post-validation" => sub {
        my $storage = encrypted_storage('test', 'test');

        $storage->encrypt;
        $storage->stage;
        $storage->make_object_path;
        $storage->move;
        ok($storage->postvalidate);
      };

      describe "#verify_crypt" => sub {
        it "fails with no encrypted zip" => sub {
          my $storage = encrypted_storage('test', 'test');

          ok(! $storage->verify_crypt());
        };

        it "fails with a corrupted encrypted zip" => sub {
          my $storage = encrypted_storage('test', 'test');
          my $encrypted = $storage->zip_source . ".gpg";

          $storage->encrypt;

          open(my $fh, "+< $encrypted") or die($!);
          seek($fh,0,0);
          print $fh "mashed potatoes";
          close($fh);

          ok(! $storage->verify_crypt());
        };

        it "succeeds with an intact encrypted zip" => sub {
          my $storage = encrypted_storage('test', 'test');

          $storage->encrypt;
          ok($storage->verify_crypt());
        };

      };

    };

  };
};

runtests unless caller;
