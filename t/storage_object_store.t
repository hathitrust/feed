use Test::Spec;
use Test::Exception;
use HTFeed::Storage::ObjectStore;

use strict;

describe "HTFeed::Storage::ObjectStore" => sub {
  spec_helper 'storage_helper.pl';
  spec_helper 's3_helper.pl';
  local our ($tmpdirs, $testlog, $bucket, $s3);

  sub object_storage {
    my $volume = stage_volume($tmpdirs,@_);

    my $storage = HTFeed::Storage::ObjectStore->new(
      name => 'objectstore-test',
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

      my $result = $s3->s3api('head-object','--key',"test.test.$storage->{timestamp}.zip");
      # openssl md5 -binary test.zip | base64
      is($result->{Metadata}{'content-md5'}, 'LUDWXBrs2Fez94DoW8m9kg==', 'metadata for md5 checksum');
    };

  };

  describe "#make_object_path" => sub {
    it "returns true" => sub {
      my $storage = object_storage('test','test');
      ok( $storage->make_object_path );
    };
  };

  describe "#postvalidate" => sub {
    before each => sub {
      $s3->rm("/","--recursive");
    };

    it "returns false without calling move (i.e. nothing in s3)" => sub {
      my $storage = object_storage('test','test');
      ok( ! $storage->postvalidate);
    };

    it "returns false if zip is not in s3" => sub {
      my $storage = object_storage('test','test');
      $storage->cp_to($storage->{volume}->get_mets_path());
      ok( ! $storage->postvalidate);
    };

    it "returns false if mets is not in s3" => sub {
      my $storage = object_storage('test','test');
      $storage->cp_to($storage->zip_source, $storage->zip_key);
      ok( ! $storage->postvalidate);
    };

    it "returns false if zip is missing checksum metadata" => sub {
      my $storage = object_storage('test','test');
      $storage->cp_to($storage->{volume}->get_mets_path(), $storage->mets_key);

      $s3->cp_to($storage->zip_source,$storage->object_path . $storage->zip_suffix);

      ok ( !$storage->postvalidate);
    };

    it "returns false if zip does not have correct checksum metadata" => sub {
      my $storage = object_storage('test','test');
      $storage->cp_to($storage->{volume}->get_mets_path,$storage->mets_key);

      $s3->cp_to($storage->zip_source,$storage->object_path . $storage->zip_suffix,
        "--metadata" => "content-md5=invalid");

      ok ( !$storage->postvalidate);
    };

    it "returns false if mets does not have correct checksum metadata" => sub {
      my $storage = object_storage('test','test');
      $storage->cp_to($storage->zip_source,$storage->zip_key);

      $s3->cp_to($storage->{volume}->get_mets_path,
        $storage->object_path . ".mets.xml",
        "--metadata" => "content-md5=invalid");

      ok ( !$storage->postvalidate);
    };

    it "returns true after successful move" => sub {
      my $storage = object_storage('test','test');
      ok($storage->move);
      ok($storage->postvalidate);
    };
  };

  describe "#record_backup" => sub {
    before each => sub {
      get_dbh()->do("DELETE FROM feed_backups");
    };

    it "records the item info in the feed_backups table" => sub {
      my $storage = object_storage('test','test');
      $storage->move;
      $storage->record_backup;

      my $r = get_dbh()->selectall_arrayref("SELECT version, path,
        saved_md5sum, storage_name from feed_backups WHERE namespace = 'test'
        and id = 'test'");

      is($r->[0][0],$storage->{timestamp});
      is($r->[0][1],"s3://$s3->{bucket}/test.test.$storage->{timestamp}");
      # md5sum test.zip - hex rather than base64 checksum here
      is($r->[0][2],"2d40d65c1aecd857b3f780e85bc9bd92");
      is($r->[0][3],$storage->{name});
    };

    it "does not record anything if the volume wasn't copied";
    it "records the checksum of the encrypted zip";
  };

  context "with encryption enabled" => sub {
    sub encrypted_object_storage {
      my $volume = stage_volume($tmpdirs,@_);

      my $storage = HTFeed::Storage::ObjectStore->new(
        name => 'objectstore-test',
        volume => $volume,
        config => {
          bucket => $s3->{bucket},
          awscli => $s3->{awscli},
          encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
        },
      );

      return $storage;
    }

    it "stores the mets and encrypted zip" => sub {
      my $storage = encrypted_object_storage('test','test');
      $storage->encrypt;
      $storage->move;

      ok($s3->s3_has("test.test.$storage->{timestamp}.zip.gpg"));
      ok(!$s3->s3_has("test.test.$storage->{timestamp}.zip"));
      ok($s3->s3_has("test.test.$storage->{timestamp}.mets.xml"));
    };

    it "saves the checksum of the encrypted zip" => sub {
      get_dbh()->do("DELETE FROM feed_backups");
      my $storage = encrypted_object_storage('test', 'test');

      $storage->encrypt;
      $storage->move;
      $storage->record_backup;

      my $r = get_dbh()->selectall_arrayref("SELECT saved_md5sum from feed_backups WHERE namespace = 'test' and id = 'test' and storage_name = 'objectstore-test'");
      my $crypted = $storage->zip_source();
      ok($crypted =~ /\.gpg$/);
      my $checksum = `md5sum $crypted | cut -f 1 -d ' '`;
      chomp $checksum;
      is($r->[0][0],$checksum);
    };
  }
};

runtests unless caller;
