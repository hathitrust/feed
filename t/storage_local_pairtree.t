use Test::Spec;
use HTFeed::Storage::LocalPairtree;

use strict;

describe "HTFeed::Storage::LocalPairtree" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);

  sub local_storage {
    my $volume = stage_volume($tmpdirs,@_);

    my $storage = HTFeed::Storage::LocalPairtree->new(
      name => 'localpairtree-test',
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

runtests unless caller;
