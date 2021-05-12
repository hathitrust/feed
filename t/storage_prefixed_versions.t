use Test::Spec;
use HTFeed::Storage::PrefixedVersions;

use strict;

describe "HTFeed::Storage::PrefixedVersions" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);

  sub storage_for_volume {
    my $volume = shift;

    my $storage = HTFeed::Storage::PrefixedVersions->new(
      name => 'prefixedversions-test',
      volume => $volume,
      config => {
        obj_dir => $tmpdirs->{obj_dir},
      }
    );

    return $storage;
  }

  sub staged_volume_storage {
    my $volume = stage_volume($tmpdirs,@_);

    return storage_for_volume($volume);

  }

  sub storage {
    my ($namespace, $objid) = @_;
    my $volume = HTFeed::Volume->new(
      namespace => $namespace,
      objid => $objid,
      packagetype => 'simple');

    return storage_for_volume($volume);
  }

  describe "#object_path" => sub {

    it "uses config for object root" => sub {
      eval {
        my $storage = storage('test', 'test');
        $storage->set_storage_config('/backup-location/obj','obj_dir');
        like( $storage->object_path(), qr{^/backup-location/obj/});
      };
    };

    it "includes the namespace and first three characters in the path for object ids >= 3 chars" => sub {
      my $storage = storage('test', 'test');

      like( $storage->object_path(), qr{/test/tes});
    };

    it "includes the namespace and all but the last four characters in the path for object ids >= 7 chars" => sub {
      my $storage = storage('test', 'test123456');

      like( $storage->object_path(), qr{/test/test12});
    };

    it "includes the entire object id in the path for object ids < 3 chars" => sub {
      my $storage = storage('test', '12');

      like( $storage->object_path(), qr{/test/12});
    }

  };

  describe "#stage" => sub {
    it "deposits to a staging area under the configured object location with the timestamp in the filename" => sub {
      my $storage = staged_volume_storage('test', 'test');
      $storage->stage;

      ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.$storage->{timestamp}.mets.xml");
      ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.$storage->{timestamp}.zip");
    }
  };

  describe "#make_object_path" => sub {
    it "makes the path" => sub {
      my $storage = storage('test','test');

      $storage->make_object_path;

      ok(-d "$tmpdirs->{obj_dir}/test/tes");
    }
  };

  describe "#move" => sub {
    it "moves from the staging location to the object path" => sub {
      my $storage = staged_volume_storage('test','test');
      $storage->stage;
      $storage->make_object_path;
      $storage->move;

      ok(-e "$tmpdirs->{obj_dir}/test/tes/test.$storage->{timestamp}.zip","copies the zip");
      ok(-e "$tmpdirs->{obj_dir}/test/tes/test.$storage->{timestamp}.mets.xml","copies the mets");
    };
  };

  describe "#record_backup" => sub {
    before each => sub {
      get_dbh()->do("DELETE FROM feed_backups");
    };

    it "records the copy in the feed_backups table" => sub {
      my $storage = staged_volume_storage('test','test');
      $storage->stage;
      $storage->make_object_path;
      $storage->move;
      $storage->record_backup;

      my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

      is($r->[0][0],$storage->{timestamp});
    };

    it "does not record anything if the volume wasn't moved" => sub {

      my $storage = staged_volume_storage('test','test');
      $storage->stage;

      eval { $storage->record_backup };

      my $r = get_dbh()->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test'");

      is(scalar(@$r),0);

    };

    it "records the full path" => sub {
      my $storage = staged_volume_storage('test','test');
      $storage->stage;
      $storage->make_object_path;
      $storage->move;
      $storage->record_backup;

      my $r = get_dbh()->selectall_arrayref("SELECT path from feed_backups WHERE namespace = 'test' and id = 'test'");

      is($r->[0][0],$storage->object_path);
    };

    it "records the storage name" => sub {
      my $storage = staged_volume_storage('test','test');
      $storage->stage;
      $storage->make_object_path;
      $storage->move;
      $storage->record_backup;

      my $r = get_dbh()->selectall_arrayref("SELECT storage_name from feed_backups WHERE namespace = 'test' and id = 'test'");

      is($r->[0][0],$storage->{name});
    };
  };

  context "with encryption enabled" => sub {
    sub encrypted_storage {
      my $volume = stage_volume($tmpdirs,@_);

      my $storage = HTFeed::Storage::PrefixedVersions->new(
        name => 'prefixedversions-test',
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

      ok(-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.$storage->{timestamp}.zip.gpg", "copies the encrypted zip");
      ok(!-e "$tmpdirs->{obj_dir}/.tmp/test.test/test.$storage->{timestamp}.zip", "does not copy the unencrypted zip");
    };

    it "puts only the encrypted zip in object storage" => sub {
      my $storage = encrypted_storage('test', 'test');
      $storage->encrypt;
      $storage->stage;
      $storage->make_object_path;
      $storage->move;

      ok(-e "$tmpdirs->{obj_dir}/test/tes/test.$storage->{timestamp}.zip.gpg","copies the encrypted zip");
      ok(! -e "$tmpdirs->{obj_dir}/test/tes/test.$storage->{timestamp}.zip","does not copy the unencrypted zip");
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

    describe "#prevalidate" => sub {
      it "fails with no encrypted zip" => sub {
        my $storage = encrypted_storage('test', 'test');
        $storage->encrypt;
        $storage->stage;
        my $volume = $storage->{volume};
        system('rm', $storage->zip_stage_path);

        ok(! $storage->prevalidate());
      };

      it "fails with a corrupted encrypted zip" => sub {
        my $storage = encrypted_storage('test', 'test');

        $storage->encrypt;
        $storage->stage;
        my $volume = $storage->{volume};
        my $encrypted = $storage->zip_stage_path;

        open(my $fh, "+< $encrypted") or die($!);
        seek($fh,0,0);
        print $fh "mashed potatoes";
        close($fh);

        ok(! $storage->prevalidate());
      };

      it "succeeds with an intact encrypted zip" => sub {
        my $storage = encrypted_storage('test', 'test');

        $storage->encrypt;
        $storage->stage;
        ok($storage->prevalidate());
      };

    };

  };

};

runtests unless caller;
