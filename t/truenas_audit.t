use Test::Spec;
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Storage::LocalPairtree;
use Data::Dumper;
use File::Copy;
use File::Pairtree qw(id2ppath s2ppchars);

use strict;
use warnings;

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
    push(@$data, $sth->fetchrow_hashref);
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
    push(@$data, $sth->fetchrow_hashref);
    return $data;
  }

  # `RepositoryIterator` can infer its sdr partition when it isn't at the root of the
  # filesystem. Hence we copy to a location where we can put "sdr1" in the path.
  sub temp_sdr_path {
    my $sdr_partition = shift || 1;

    return "$tmpdirs->{tmpdir}/sdr$sdr_partition";
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
    my $temp_sdr_path = temp_sdr_path;
    File::Path::make_path("$temp_sdr_path/obj");
    `cp -r $tmpdirs->{obj_dir}/* $temp_sdr_path/obj/`;
    # This is just conforming to `etc/config_test.yml` so Volume.pm can find the files.
    File::Path::make_path("/tmp/obj_link/test/$pt_path");
    `ln -s $temp_sdr_path/obj/test/$pt_path/$pt_objid /tmp/obj_link/test/$pt_path`;
  };

  after each => sub {
    File::Path::remove_tree(temp_sdr_path);
    File::Path::remove_tree('/tmp/obj_link');
    get_dbh->prepare('DELETE FROM feed_storage')->execute;
    get_dbh->prepare('DELETE FROM feed_audit_detail')->execute;
  };

  foreach my $storage_name (('s3-truenas-macc', 's3-truenas-ictc')) {
    it "writes to feed_storage" => sub {
      my $temp_sdr_path = temp_sdr_path;
      `bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path`;
      my $db_data = get_feed_storage_data('test', 'test', $storage_name);
      is(scalar(@$db_data), 1, 'with only one initial entry');      
      is($db_data->[0]->{namespace}, 'test', 'correct namespace');
      is($db_data->[0]->{id}, 'test', 'correct id');
      is($db_data->[0]->{storage_name}, $storage_name, 'correct storage_name');
      ok($db_data->[0]->{zip_size} > 0, 'nonzero zip_size');
      ok($db_data->[0]->{mets_size} > 0, 'nonzero mets_size');
      ok(!defined $db_data->[0]->{saved_md5sum}, 'not defined saved_md5sum');
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
    `bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path`;
    my $db_data = get_feed_storage_data('test', 'test', $storage_name);
    is(scalar(@$db_data), 1, 'with only one initial entry');
    my $old_lastchecked = $db_data->[0]->{lastchecked};
    my $old_lastmd5check = $db_data->[0]->{lastmd5check};
    sleep 1;
    `bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path`;
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
    # Fiddle with the zip
    my $pt_objid = s2ppchars($objid);
    my $pt_path = id2ppath($objid);
    my $zip_path = "$temp_sdr_path/obj/test/$pt_path$pt_objid/" . "$objid.zip";
    open(my $fh, '>', $zip_path) or die "open zip file $zip_path failed: $!";
    print $fh "shwoozle\n";
    close($fh);
    `bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path`;
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
    my $pt_objid = s2ppchars($objid);
    my $pt_path = id2ppath($objid);
    foreach my $ext (('silly', 'pre_uplift.mets.xml')) {
      my $path = "$temp_sdr_path/obj/test/$pt_path$pt_objid/" . "$objid.$ext";
      `touch $path`;
    }
    `bin/audit/truenas_audit.pl --md5 --storage_name $storage_name $temp_sdr_path`;
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
};

runtests unless caller;
