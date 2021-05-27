use Test::Spec;
use HTFeed::Storage::LinkedPairtree;

use strict;

describe "HTFeed::Storage::LinkedPairtree" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);

  sub make_old_version_other_dir {
    my $volume = stage_volume($tmpdirs,@_);

    my $storage = HTFeed::Storage::LinkedPairtree->new(
      name => 'linkedpairtree-test',
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
      name => 'linkedpairtree-test',
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

runtests unless caller;
