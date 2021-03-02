use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(stage_volume);
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);

use HTFeed::Stage::StorageMigrate;
use File::Path qw(remove_tree);
use File::Basename qw(dirname);
use File::Pairtree qw(id2ppath s2ppchars);
use strict;

describe "HTFeed::Stage::StorageMigrate" => sub {

  spec_helper 's3_helper.pl';
  spec_helper 'storage_helper.pl';

  local our ($bucket, $s3, $tmpdirs, $testlog);
  my $old_storage_classes;

  before each => sub {
    $old_storage_classes = get_config('storage_migrate');
    my $new_storage_classes = [
      {
        class => 'HTFeed::Storage::VersionedPairtree',
        obj_dir => $tmpdirs->{backup_obj_dir},
        encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
      },
      {
        class => 'HTFeed::Storage::ObjectStore',
        bucket => $s3->{bucket},
        awscli => $s3->{awscli},
        encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
      }
    ];
    set_config($new_storage_classes,'storage_migrate');
  };

  after each => sub {
    set_config($old_storage_classes,'storage_migrate');
  };

  sub copy_to_repo {
    my $namespace = shift;
    my $objid = shift;
    my $tmpdirs = shift;

    my $pt_objid = s2ppchars($objid);
    my $pt_path = id2ppath($objid);

    my $objdir = "$tmpdirs->{obj_dir}/test/$pt_path/$pt_objid";
    my $link_base = "$tmpdirs->{link_dir}/test/$pt_path";

    my $mets = $tmpdirs->test_home . "/fixtures/volumes/$pt_objid.mets.xml";
    my $zip = $tmpdirs->test_home . "/fixtures/volumes/$pt_objid.zip";

    system("mkdir -p $objdir");
    system("mkdir -p $link_base");
    system("ln -s $objdir $link_base");
    system("cp $zip $objdir/$pt_objid.zip");
    system("cp $mets $objdir/$pt_objid.mets.xml");
  }

  sub test_storage_migrate {
    my $namespace = shift;
    my $objid = shift;
    my $tmpdirs = shift;

    my $pt_objid = s2ppchars($objid);
    my $obj_path = "$namespace/" . id2ppath($objid) . '/' . $pt_objid;

    # then run the storage migration and make sure volumes show up in the
    # expected location
    my $volume = HTFeed::Volume->new(namespace => $namespace, objid => $objid, packagetype => 'ht');
    my $stage = HTFeed::Stage::StorageMigrate->new(volume => $volume);
    $stage->run;

    my $dbh = get_dbh();
    my $audits = $dbh->selectall_arrayref("SELECT * from feed_audit WHERE namespace = '$namespace' and id = '$objid'");
    my $versioned_backup = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = '$namespace' and id = '$objid' and path like ?",undef,$tmpdirs->{backup_obj_dir} . '%');
    my $s3_backup = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = '$namespace' and id = '$objid' and path like ?",undef,"s3://$bucket%");

    is(scalar(@{$versioned_backup}),1,'records a backup for versioned pairtree');
    is(scalar(@{$s3_backup}),1,'records a backup for object store');

    my $timestamp = $versioned_backup->[0][0];
    ok(-e "$tmpdirs->{backup_obj_dir}/$obj_path/$timestamp/$pt_objid.zip.gpg","copies the encrypted zip to backup storage");
    ok(-e "$tmpdirs->{backup_obj_dir}/$obj_path/$timestamp/$pt_objid.mets.xml","copies the mets backup storage");

    my $s3_timestamp = $s3_backup->[0][0];
    ok($s3->s3_has("$namespace.$pt_objid.$s3_timestamp.zip.gpg"),"copies the zip to s3");
    ok($s3->s3_has("$namespace.$pt_objid.$s3_timestamp.mets.xml"),"copies the mets to s3");

    ok($stage->succeeded);
  }

  sub dir_is_empty {
    my $dirname = shift;
    opendir(my $dh, $dirname) or die "$dirname doesn't exist or is not a directory";
    return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0;
  }

  it "copies from the repository to all configured storages" => sub {
    my $namespace = 'test';
    my $objid = 'test';

    copy_to_repo($namespace,$objid,$tmpdirs);
    test_storage_migrate($namespace,$objid,$tmpdirs);
  };

  it "copies items that don't meet current specs" => sub {
    my $namespace = 'test';
    my $objid = "extra_files_in_zip";

    copy_to_repo($namespace,$objid,$tmpdirs);
    test_storage_migrate($namespace,$objid,$tmpdirs);

  };

  it "clean leaves files in the repo untouched on success" => sub {
    my $namespace = 'test';
    my $objid = 'test';
    my $pt_objid = s2ppchars($objid);
    my $obj_path = "$namespace/" . id2ppath($objid) . '/' . $pt_objid;

    copy_to_repo($namespace,$objid,$tmpdirs);

    my $volume = HTFeed::Volume->new(namespace => $namespace, objid => $objid, packagetype => 'ht');
    my $stage = HTFeed::Stage::StorageMigrate->new(volume => $volume);

    # pretend success
    $stage->{has_run} = 1;
    $stage->{failed} = 0;

    $stage->clean;

    ok(-e "$tmpdirs->{obj_dir}/$obj_path/$pt_objid.zip");
    ok(-e "$tmpdirs->{obj_dir}/$obj_path/$pt_objid.mets.xml");
  };

  it "clean leaves files in the repo untouched on failure" => sub {
    my $namespace = 'test';
    my $objid = 'test';
    my $pt_objid = s2ppchars($objid);
    my $obj_path = "$namespace/" . id2ppath($objid) . '/' . $pt_objid;

    copy_to_repo($namespace,$objid,$tmpdirs);

    my $volume = HTFeed::Volume->new(namespace => $namespace, objid => $objid, packagetype => 'ht');
    my $stage = HTFeed::Stage::StorageMigrate->new(volume => $volume);

    # pretend failure
    $stage->{has_run} = 1;
    $stage->{failed} = 1;

    $stage->clean;

    ok(-e "$tmpdirs->{obj_dir}/$obj_path/$pt_objid.zip");
    ok(-e "$tmpdirs->{obj_dir}/$obj_path/$pt_objid.mets.xml");
  };

  it "doesn't leave behind garbage in staging directories" => sub {
    my $namespace = 'test';
    my $objid = 'test';

    copy_to_repo($namespace,$objid,$tmpdirs);

    my $volume = HTFeed::Volume->new(namespace => $namespace, objid => $objid, packagetype => 'ht');
    my $stage = HTFeed::Stage::StorageMigrate->new(volume => $volume);

    $stage->run;
    ok($stage->succeeded);

    foreach my $dirtype ($tmpdirs->staging_dirtypes) {
      ok(dir_is_empty($tmpdirs->{$dirtype}),"$dirtype dir is empty");
    }

  }
};

runtests unless caller;
