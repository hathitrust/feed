use Test::Spec;
use Test::Exception;
use HTFeed::Storage::ObjectStore;

use strict;

describe "HTFeed::Storage::ObjectStore" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog, $bucket, $s3);

  before all => sub {
    $bucket = "bucket" . sprintf("%08d",rand(1000000));
    $s3 = HTFeed::Storage::S3->new(
      bucket => $bucket,
      awscli => ['aws','--endpoint-url','http://minio:9000']
    );
    $ENV{AWS_MAX_ATTEMPTS} = 1;

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
      $storage->put_mets;
      ok( ! $storage->postvalidate);
    };

    it "returns false if mets is not in s3" => sub {
      my $storage = object_storage('test','test');
      ok( ! $storage->postvalidate);
    };

    it "returns false if zip is missing checksum metadata" => sub {
      my $storage = object_storage('test','test');
      $storage->put_mets;

      $s3->s3api("put-object",
        "--key",$storage->object_path . $storage->zip_suffix,
        "--body",$storage->zip_source);

      ok ( !$storage->postvalidate);
    };

    it "returns false if zip does not have correct checksum metadata" => sub {
      my $storage = object_storage('test','test');
      $storage->put_mets;

      $s3->s3api("put-object",
        "--key",$storage->object_path . $storage->zip_suffix,
        "--body",$storage->zip_source,
        "--metadata" => "content-md5=invalid");

      ok ( !$storage->postvalidate);
    };

    it "returns false if mets does not have correct checksum metadata" => sub {
      my $storage = object_storage('test','test');
      $storage->put_zip;

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

  describe "#record_audit" => sub {
    it "records the backup";
    it "records the checksum of the encrypted zip";
  };
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
