use HTFeed::Config qw(get_config);
use Test::Spec;
use Test::Exception;
use HTFeed::Storage::PairtreeObjectStore;

use strict;

describe "HTFeed::Storage::PairtreeObjectStore" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog, $bucket, $s3);

  before all => sub {
    $bucket = "bucket" . sprintf("%08d",rand(1000000));
    $s3 = HTFeed::Storage::S3->new(
      bucket => $bucket,
      awscli => get_config('versitygw_awscli')
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

    my $storage = HTFeed::Storage::PairtreeObjectStore->new(
      name => 'pairtreeobjectstore-test',
      volume => $volume,
      config => {
        bucket => $s3->{bucket},
        awscli => $s3->{awscli}
      },
    );

    return $storage;
  }

  describe "#object_path" => sub {
    it "includes the namespace, pairtree path, and pairtreeized object id" => sub {
      my $storage = object_storage('test','ark:/123456/abcde');

      is($storage->object_path, "test/pairtree_root/ar/k+/=1/23/45/6=/ab/cd/e/ark+=123456=abcde/");
    };
  };

  describe "#move" => sub {
    before each => sub {
      $s3->rm("/","--recursive");
    };

    it "uploads zip and mets" => sub {
      my $storage = object_storage('test','test');
      $storage->move;

      ok($s3->s3_has("test/pairtree_root/te/st/test/test.zip"));
      ok($s3->s3_has("test/pairtree_root/te/st/test/test.mets.xml"));
    };

  };

  describe "#record_audit" => sub {
    it "records the item info in the feed_audit table";
    it "does something with the sdr bucket";
  };

  it "deals with old symlinks";

};

runtests unless caller;
