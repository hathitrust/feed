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

    # basically we want to test that we're properly using the checksum verification
    it "passes --content-md5 argument" => sub {
      my $storage = object_storage('test','test');
      my $mock_s3 = HTFeed::Test::MockS3->new();
      $storage->{s3} = $mock_s3;

      $storage->move;

      # openssl md5 -binary test.mets.xml | base64
      like($mock_s3->{calls}[0],qr(.*test.mets.xml.*--content-md5 YqtkiMjGHD6t4tiKsERIFA==));
      # openssl md5 -binary test.zip | base64
      like($mock_s3->{calls}[1],qr(.*test.zip.*--content-md5 LUDWXBrs2Fez94DoW8m9kg==));

    };

    it "S3 storage call fails if provided md5 is wrong" => sub {
      my $storage = object_storage('test','test');

      my $s3 = $storage->{s3};

      dies_ok( sub {
        $s3->s3api("put-object",
          "--key","test-wrong-md5",
          "--body",$storage->zip_source,
          # echo 'mashed potatoes' | openssl md5 --binary | base64
          "--content-md5",'8wSepo2ze/YjjW1rawM6Lg==');
      });
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
      $storage->put_object($storage->mets_key,$storage->{volume}->get_mets_path());
      ok( ! $storage->postvalidate);
    };

    it "returns false if mets is not in s3" => sub {
      my $storage = object_storage('test','test');
      $storage->put_object($storage->zip_key,$storage->zip_source);
      ok( ! $storage->postvalidate);
    };

    it "returns false if zip is missing checksum metadata" => sub {
      my $storage = object_storage('test','test');
      $storage->put_object($storage->mets_key,$storage->{volume}->get_mets_path());

      $s3->s3api("put-object",
        "--key",$storage->object_path . $storage->zip_suffix,
        "--body",$storage->zip_source);

      ok ( !$storage->postvalidate);
    };

    it "returns false if zip does not have correct checksum metadata" => sub {
      my $storage = object_storage('test','test');
      $storage->put_object($storage->mets_key,$storage->{volume}->get_mets_path());

      $s3->s3api("put-object",
        "--key",$storage->object_path . $storage->zip_suffix,
        "--body",$storage->zip_source,
        "--metadata" => "content-md5=invalid");

      ok ( !$storage->postvalidate);
    };

    it "returns false if mets does not have correct checksum metadata" => sub {
      my $storage = object_storage('test','test');
      $storage->put_object($storage->zip_key,$storage->zip_source);

      $s3->s3api("put-object",
        "--key",$storage->object_path . ".mets.xml",
        "--body",$storage->{volume}->get_mets_path(),
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
        saved_md5sum from feed_backups WHERE namespace = 'test' and id =
        'test'");

      is($r->[0][0],$storage->{timestamp});
      is($r->[0][1],"s3://$s3->{bucket}/test.test.$storage->{timestamp}");
      # md5sum test.zip - hex rather than base64 checksum here
      is($r->[0][2],"2d40d65c1aecd857b3f780e85bc9bd92");
    };

    it "does not record anything if the volume wasn't copied";
    it "records the checksum of the encrypted zip";
  };

  context "with encryption enabled" => sub {
    sub encrypted_object_storage {
      my $volume = stage_volume($tmpdirs,@_);

      my $storage = HTFeed::Storage::ObjectStore->new(
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

      my $r = get_dbh()->selectall_arrayref("SELECT saved_md5sum from feed_backups WHERE namespace = 'test' and id = 'test'");
      my $crypted = $storage->zip_source();
      ok($crypted =~ /\.gpg$/);
      my $checksum = `md5sum $crypted | cut -f 1 -d ' '`;
      chomp $checksum;
      is($r->[0][0],$checksum);
    };
  }
};

runtests unless caller;

package HTFeed::Test::MockS3;

sub new {
  my $class = shift;

  my $self = {
    calls => []
  };

  return bless($self,$class);
}

sub s3api {
  my $self = shift;
  push(@{$self->{calls}},join(' ',@_));
}
