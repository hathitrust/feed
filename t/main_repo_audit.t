use Test::Spec;
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Storage::LocalPairtree;
use Capture::Tiny;
use File::Copy;
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path;

use strict;

describe "bin/audit/main_repo_audit.pl" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);

  sub local_storage {
    my $volume = stage_volume($tmpdirs,@_);

    my $storage = HTFeed::Storage::LocalPairtree->new(
      name => 'localpairtree-test',
      volume => $volume,
      config => {
        obj_dir => $tmpdirs->{obj_dir}
      }
    );
    return $storage;
  }

  sub count_feed_audit_entries {
    my $namespace = shift;
    my $objid = shift;
    my $storage_name = shift;
    my $sdr_partition = shift;

    my $sql = 'SELECT COUNT(*) FROM feed_audit WHERE namespace=? AND id=? AND storage_name=? AND sdr_partition=?';
    my $sth = get_dbh()->prepare($sql);
    $sth->execute($namespace, $objid, $storage_name, $sdr_partition);
    if (my @row = $sth->fetchrow_array()) {
      return $row[0];
    } else {
      return 0;
    }
  }

  before each => sub {
    my $namespace = 'test';
    my $objid = 'test';
    my $storage = local_storage($namespace, $objid);
    $storage->stage;
    $storage->make_object_path;
    $storage->move;
    my $pt_objid = s2ppchars($objid);
    my $pt_path = id2ppath($objid);
    # main_repo_audit.pl can infer its sdr partition when it isn't at the root of the
    # filesystem but the `tmpdirs` random names will throw it off completely. Hence we
    # copy to a location where we can put "sdr1" in the path.
    File::Path::make_path('/tmp/sdr1/obj');
    `cp -r $tmpdirs->{obj_dir}/* /tmp/sdr1/obj/`;
    # This is just conforming to `etc/config_test.yml` so Volume.pm can find the files.
    File::Path::make_path("/tmp/obj_link/test/$pt_path");
    `ln -s /tmp/sdr1/obj/test/$pt_path/$pt_objid /tmp/obj_link/test/$pt_path`;
  };
  
  after each => sub {
    File::Path::remove_tree('/tmp/sdr1');
    File::Path::remove_tree('/tmp/obj_link');
  };

  describe 'at macc' => sub {
    it "succeeds" => sub {
      `bin/audit/main_repo_audit.pl --md5 --storage_name s3-truenas-macc /tmp/sdr1`;
      is(count_feed_audit_entries('test', 'test', 's3-truenas-macc', 1), 1, 'one feed_audit entry');
    };
  };

  describe 'at ictc' => sub {
    it "succeeds" => sub {
      `bin/audit/main_repo_audit.pl --md5 --storage_name s3-truenas-ictc /tmp/sdr1`;
      is(count_feed_audit_entries('test', 'test', 's3-truenas-ictc', 1), 1, 'one feed_audit entry');
    };
  };
};

runtests unless caller;
