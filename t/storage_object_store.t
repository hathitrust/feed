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

      #  my $result = $s3->s3api('head-object',"test.test.$storage->{timestamp}.zip");
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

runtests unless caller;
