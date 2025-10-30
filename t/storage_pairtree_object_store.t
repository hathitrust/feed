use HTFeed::Config qw(get_config);
use Test::Spec;
use Test::Exception;
use File::Temp qw(tempdir);
use File::Basename qw(basename);
use File::Path qw(make_path remove_tree);
use HTFeed::Storage::PairtreeObjectStore;

use strict;

describe "HTFeed::Storage::PairtreeObjectStore" => sub {
  spec_helper 'storage_helper.pl';
  spec_helper 's3_helper.pl';

  my $vgw_home = "$ENV{FEED_HOME}/var/vgw";
  local our ($tmpdirs, $testlog, $bucket, $s3, $objdir, $bucket_dir);

  before each => sub {
    $s3->rm("/","--recursive");
  };

  before all => sub {
    $bucket_dir = "$vgw_home/$bucket/obj";
    $objdir = "$vgw_home/$bucket-obj/obj";
    make_path($objdir);
  };

  after all => sub {
    remove_tree($objdir,$bucket_dir);
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

      is($storage->object_path, "obj/test/pairtree_root/ar/k+/=1/23/45/6=/ab/cd/e/ark+=123456=abcde/");
    };
  };

  describe "#move" => sub {
    it "uploads zip and mets" => sub {
      my $storage = object_storage('test','test');
      my $pt_path = "test/pairtree_root/te/st/test";
      $storage->move;

      # should be in the bucket and also visible in the filesystem
      ok($s3->s3_has("obj/$pt_path/test.zip"));
      ok($s3->s3_has("obj/$pt_path/test.mets.xml"));
      ok(-s "$bucket_dir/$pt_path/test.zip");
      ok(-s "$bucket_dir/$pt_path/test.mets.xml");
    };

  };

  describe "#record_audit" => sub {
    it "records the item info in the feed_storage table" => sub {
      my $dbh = get_dbh();

      my $storage = object_storage('test','test');
      $storage->stage;
      $storage->make_object_path;
      $storage->move;
      $storage->record_audit;

      my $r = $dbh->selectall_arrayref("SELECT * from feed_storage WHERE namespace = 'test' and id = 'test' and storage_name='pairtreeobjectstore-test'");

      ok($r->[0][0]);

    };
  };

  it "writes through existing symlinks" => sub {

    my $pt_prefix = "test/pairtree_root/te/st";

    # set things up using filesystem access rather than via s3
    make_path("$objdir/$pt_prefix/test","$bucket_dir/$pt_prefix");
    system("touch $objdir/$pt_prefix/test/test.zip");
    system("touch $objdir/$pt_prefix/test/test.mets.xml");
    system("ln -sv $objdir/$pt_prefix/test $bucket_dir/$pt_prefix/test");

    # writes via the symlink in $bucket_dir
    my $storage = object_storage('test','test');
    $storage->move;

    # started as zero size (via touch), should be nonzero size now
    ok(-s "$objdir/$pt_prefix/test/test.zip");
    ok(-s "$objdir/$pt_prefix/test/test.mets.xml");

    # should still be a link in the bucket dir
    ok(-l "$bucket_dir/$pt_prefix/test");
  };

};

runtests unless caller;
