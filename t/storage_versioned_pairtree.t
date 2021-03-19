use Test::Spec;
use HTFeed::Storage::VersionedPairtree;

use strict;

describe "HTFeed::Storage::VersionedPairtree" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);

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
    before each => sub {
      get_dbh()->do("DELETE FROM feed_backups");
    };

    it "records the copy in the feed_backups table" => sub {
      my $storage = versioned_storage('test','test');
      $storage->stage;
      $storage->make_object_path;
      $storage->move;
      $storage->record_backup;

      my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

      is($r->[0][0],$storage->{timestamp});
    };

    it "does not record anything if the volume wasn't moved" => sub {

      my $storage = versioned_storage('test','test');
      $storage->stage;

      eval { $storage->record_backup };

      my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

      is(scalar(@$r),0);

    };

    it "records the full path" => sub {
      my $storage = versioned_storage('test','test');
      $storage->stage;
      $storage->make_object_path;
      $storage->move;
      $storage->record_backup;

      my $r = get_dbh()->selectall_arrayref("SELECT path from feed_backups WHERE namespace = 'test' and id = 'test'");

      is($r->[0][0],$storage->object_path);
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

        $storage->encrypt;
        my $encrypted = $storage->zip_source;

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

runtests unless caller;
