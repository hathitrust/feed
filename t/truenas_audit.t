use strict;
use warnings;

use Data::Dumper;
use File::Copy;
use File::Pairtree qw(id2ppath s2ppchars);
use File::Spec;
use Test::Spec;

use HTFeed::DBTools qw(get_dbh);
use HTFeed::Storage::LocalPairtree;

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

  # Returns the data as arrayref of hashref
  sub get_feed_storage_data {
    my $namespace = shift;
    my $objid = shift;
    my $storage_name = shift;

    my $data = [];
    my $sql = 'SELECT * FROM feed_storage WHERE namespace=? AND id=? AND storage_name=?';
    my $sth = get_dbh()->prepare($sql);
    $sth->execute($namespace, $objid, $storage_name);
    while (my $row = $sth->fetchrow_hashref) {
      push(@$data, $row);
    }
    return $data;
  }
  
  # Returns the data as arrayref of hashref
  sub get_feed_audit_detail_data {
    my $namespace = shift;
    my $objid = shift;
    my $storage_name = shift;

    my $data = [];
    my $sql = 'SELECT * FROM feed_audit_detail WHERE namespace=? AND id=? AND storage_name=?';
    my $sth = get_dbh()->prepare($sql);
    $sth->execute($namespace, $objid, $storage_name);
    while (my $row = $sth->fetchrow_hashref) {
      push(@$data, $row);
    }
    return $data;
  }

  # `RepositoryIterator` can infer its sdr partition when it isn't at the root of the
  # filesystem but it does need an "sdrX" directory _somewhere_ in the path. We can't use
  # `$tmpdirs->{obj_dir}` by itself.
  sub temp_sdr_path {
    my $sdr_partition = shift || 1;

    return File::Spec->catfile($tmpdirs->{tmpdir}, "sdr$sdr_partition");
  }

  sub temp_sdr_obj_path {
    my $sdr_partition = shift || 1;
    my $namespace = shift || 'test';
    my $objid = shift || 'test';

    return File::Spec->catfile(
      temp_sdr_path($sdr_partition),
      'obj',
      $namespace,
      id2ppath($objid),
      s2ppchars($objid)
    );
  }

  sub temp_link_path {
    my $namespace = shift || 'test';
    my $objid = shift || 'test';

    return File::Spec->catfile(
      File::Spec->rootdir,
      'tmp',
      'obj_link',
      $namespace,
      id2ppath($objid),
      s2ppchars($objid)
    );
  }

  # Set up sdr1 and sdr2 directories with the appropriate linkage from latter to former.
  # Copy contents from `$tempdirs->{obj_dir}` into a local sdr2 so `RepositoryIterator` has
  # the proprioceptive stimulus (i.e., a directory named "sdr2" somewhere in the path) it needs.
  sub make_test_directories {
    my $namespace = shift;
    my $objid = shift;
    my $sdr2_path = temp_sdr_path(2);
    my $sdr1_obj_path = temp_sdr_obj_path(1);
    my $sdr2_obj_path = temp_sdr_obj_path(2);
    my $temp_link_path = temp_link_path;

    File::Path::make_path("$sdr2_obj_path");
    system("cp -r $tmpdirs->{obj_dir}/* $sdr2_path/obj/");
    # Symlink into obj_link so Volume.pm can find the files,
    # and into sdr1 for symlink checks inside truenas_audit.pl
    # Create directory structures but remove the leaf node so we can recreate it as a symlink.
    # This is kind of silly but trying to create a partial path would be messier.
    File::Path::make_path($temp_link_path);
    File::Path::remove_tree($temp_link_path);
    File::Path::make_path($sdr1_obj_path);
    File::Path::remove_tree($sdr1_obj_path);
    system("ln -sf $sdr2_obj_path $temp_link_path");
    system("ln -sf $sdr2_obj_path $sdr1_obj_path");
  }

  before each => sub {
    my $namespace = 'test';
    my $objid = 'test';
    my $storage = local_storage($namespace, $objid);
    $storage->stage;
    $storage->make_object_path;
    $storage->move;
    make_test_directories($namespace, $objid);
  };

  after each => sub {
    File::Path::remove_tree(temp_sdr_path);
    File::Path::remove_tree(temp_sdr_path(2));
    File::Path::remove_tree('/tmp/obj_link');
    get_dbh->prepare('DELETE FROM feed_storage')->execute;
    get_dbh->prepare('DELETE FROM feed_audit_detail')->execute;
  };

  foreach my $storage_name (('s3-truenas-macc', 's3-truenas-ictc')) {
    it "writes to feed_storage" => sub {
      my $temp_sdr_path = temp_sdr_path;
      system("bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path");
      my $db_data = get_feed_storage_data('test', 'test', $storage_name);
      is(scalar(@$db_data), 1, 'with only one initial entry');      
      is($db_data->[0]->{namespace}, 'test', 'correct namespace');
      is($db_data->[0]->{id}, 'test', 'correct id');
      is($db_data->[0]->{storage_name}, $storage_name, 'correct storage_name');
      ok($db_data->[0]->{zip_size} > 0, 'nonzero zip_size');
      ok($db_data->[0]->{mets_size} > 0, 'nonzero mets_size');
      is(length $db_data->[0]->{saved_md5sum}, 32, 'saved_md5sum is 32 characters');
      ok(defined $db_data->[0]->{deposit_time}, 'defined deposit_time');
      ok(defined $db_data->[0]->{lastchecked}, 'defined lastchecked');
      ok(defined $db_data->[0]->{lastmd5check}, 'defined lastmd5check');
      is($db_data->[0]->{md5check_ok}, 1, 'md5check_ok=1');
    };
  }

  # If existing data, only `lastchecked` and `lastmd5check` will change
  # (file sizes will also be updated but with the same data).
  it "updates existing data" => sub {
    my $temp_sdr_path = temp_sdr_path;
    my $storage_name = 's3-truenas-macc';
    system("bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path");
    my $db_data = get_feed_storage_data('test', 'test', $storage_name);
    is(scalar(@$db_data), 1, 'with only one initial entry');
    my $old_lastchecked = $db_data->[0]->{lastchecked};
    my $old_lastmd5check = $db_data->[0]->{lastmd5check};
    sleep 1;
    system("bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path");
    $db_data = get_feed_storage_data('test', 'test', $storage_name);
    my $new_lastchecked = $db_data->[0]->{lastchecked};
    my $new_lastmd5check = $db_data->[0]->{lastmd5check};
    is(scalar(@$db_data), 1, 'with only one final entry');
    isnt($old_lastchecked, $new_lastchecked, 'with changed `lastchecked`');
    isnt($old_lastmd5check, $new_lastmd5check, 'with changed `lastmd5check`');
  };

  it "records a failed MD5 check" => sub {
    my $temp_sdr_path = temp_sdr_path;
    my $storage_name = 's3-truenas-macc';
    my $objid = 'test';
    # Replace the zip with garbage
    my $zip_path = File::Spec->catfile(temp_sdr_obj_path,  "$objid.zip");
    open(my $fh, '>', $zip_path) or die "open zip file $zip_path failed: $!";
    print $fh "shwoozle\n";
    close($fh);
    system("bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path");
    my $db_data = get_feed_storage_data('test', 'test', $storage_name);
    is(scalar(@$db_data), 1, 'with only one initial feed_storage entry');
    ok(defined $db_data->[0]->{lastchecked}, 'defined lastchecked');
    ok(defined $db_data->[0]->{lastmd5check}, 'defined lastmd5check');
    is($db_data->[0]->{md5check_ok}, 0, 'md5check_ok=0');
    my $detail_data = get_feed_audit_detail_data('test', 'test', $storage_name);
    is(scalar(@$detail_data), 1, 'with one feed_audit_detail entry');
    is($detail_data->[0]->{namespace}, 'test', 'feed_audit_detail namespace');
    is($detail_data->[0]->{id}, 'test', 'feed_audit_detail id');
    is($detail_data->[0]->{storage_name}, $storage_name, 'feed_audit_detail storage_name');
    # The path for these examples is via the symlink, so it will be different from the $zip_path we fiddled with
    ok($detail_data->[0]->{path} =~ /\.zip$/, 'feed_audit_detail path');
    is($detail_data->[0]->{status}, 'BAD_CHECKSUM', 'feed_audit_detail status');
    ok($detail_data->[0]->{detail} =~ /expected=/, 'feed_audit_detail detail');
    ok(defined $detail_data->[0]->{time}, 'feed_audit_detail time defined');
  };

  it "records a spurious file but ignores pre-uplift METS" => sub {
    my $temp_sdr_path = temp_sdr_path;
    my $storage_name = 's3-truenas-macc';
    my $objid = 'test';
    # Add a silly file and a pre-uplift file (can be empty, contents don't matter)
    foreach my $ext (('silly', 'pre_uplift.mets.xml')) {
      my $path = File::Spec->catfile(temp_sdr_obj_path, "$objid.$ext");
      system("touch $path");
    }
    system("bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path");
    my $db_data = get_feed_storage_data('test', 'test', $storage_name);
    is(scalar(@$db_data), 1, 'with only one feed_storage entry');
    is($db_data->[0]->{md5check_ok}, 1, 'md5check_ok=1');
    my $detail_data = get_feed_audit_detail_data('test', 'test', $storage_name);
    is(scalar(@$detail_data), 1, 'with one feed_audit_detail entry');
    is($detail_data->[0]->{namespace}, 'test', 'feed_audit_detail namespace');
    is($detail_data->[0]->{id}, 'test', 'feed_audit_detail id');
    is($detail_data->[0]->{storage_name}, $storage_name, 'feed_audit_detail storage_name');
    ok(defined $detail_data->[0]->{path}, 'feed_audit_detail path defined');
    is($detail_data->[0]->{status}, 'BAD_FILE', 'feed_audit_detail status');
    ok($detail_data->[0]->{detail} =~ /silly/, 'feed_audit_detail detail');
    ok(defined $detail_data->[0]->{time}, 'feed_audit_detail time defined');
  };

  # For symlink checks we use sdr2 so the symlinks in sdr1 can be verified to point to
  # the right place in sdr2.
  it "checks symlinks" => sub {
    my $temp_sdr_path = temp_sdr_path(2);
    my $storage_name = 's3-truenas-macc';
    system("bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path");
    my $db_data = get_feed_storage_data('test', 'test', $storage_name);
    is(scalar(@$db_data), 1, 'with feed_storage entry');
    my $detail_data = get_feed_audit_detail_data('test', 'test', $storage_name);
    is(scalar(@$detail_data), 0, 'with no feed_audit_detail entries');
  };

  it "detects bad symlinks" => sub {
    my $temp_sdr_path = temp_sdr_path(2);
    my $storage_name = 's3-truenas-macc';

    # Remove the symlink on sdr1 and replace it with a link to somewhere else
    my $sdr1_link_location = temp_sdr_obj_path;
    # "Somewhere else" is /dev/null
    # Create a symlink clobbering the existing one without following it
    system("ln -sfn /dev/null $sdr1_link_location");

    system("bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path");
    my $db_data = get_feed_storage_data('test', 'test', $storage_name);
    is(scalar(@$db_data), 1, 'with feed_storage entry');
    my $detail_data = get_feed_audit_detail_data('test', 'test', $storage_name);
    is(scalar(@$detail_data), 1, 'with one feed_audit_detail entry');
    is($detail_data->[0]->{namespace}, 'test', 'feed_audit_detail namespace');
    is($detail_data->[0]->{id}, 'test', 'feed_audit_detail id');
    is($detail_data->[0]->{storage_name}, $storage_name, 'feed_audit_detail storage_name');
    ok($detail_data->[0]->{path} =~ /sdr2/, 'feed_audit_detail path implicates sdr2');
    is($detail_data->[0]->{status}, 'SYMLINK_INVALID', 'feed_audit_detail status');
    ok($detail_data->[0]->{detail} =~ /null/, 'feed_audit_detail detail');
    ok(defined $detail_data->[0]->{time}, 'feed_audit_detail time defined');
  };
};

runtests unless caller;
