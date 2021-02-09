use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport qw(stage_volume);
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);

use HTFeed::Stage::StorageMigrate;
use File::Path qw(remove_tree);
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

  it "copies from the repository to all configured storages" => sub {
    my $init_volume = stage_volume($tmpdirs,'test','test');

    # deposit the test item in the main repository, but not to the configured
    # backup locations
    my $local_storage = HTFeed::Storage::LocalPairtree->new(
      volume => $init_volume,
      config => { obj_dir => $tmpdirs->{obj_dir} }
    );
    my $collate = HTFeed::Stage::Collate->new(volume => $init_volume);
    $collate->run($local_storage);
    ok($collate->succeeded());


    # then run the storage migration and make sure volumes show up in the
    # expected location
    my $volume = HTFeed::Volume->new(namespace => 'test', objid => 'test', packagetype => 'ht');
    my $stage = HTFeed::Stage::StorageMigrate->new(volume => $volume);
    $stage->run;

    my $dbh = get_dbh();
    my $audits = $dbh->selectall_arrayref("SELECT * from feed_audit WHERE namespace = 'test' and id = 'test'");
    my $versioned_backup = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test' and path like ?",undef,$tmpdirs->{backup_obj_dir} . '%');
    my $s3_backup = $dbh->selectall_arrayref("SELECT version from feed_backups WHERE namespace = 'test' and id = 'test' and path like ?",undef,"s3://$bucket%");

    is(scalar(@{$versioned_backup}),1,'records a backup for versioned pairtree');
    is(scalar(@{$s3_backup}),1,'records a backup for object store');

    my $timestamp = $versioned_backup->[0][0];
    ok(-e "$tmpdirs->{backup_obj_dir}/test/pairtree_root/te/st/test/$timestamp/test.zip.gpg","copies the encrypted zip to backup storage");
    ok(-e "$tmpdirs->{backup_obj_dir}/test/pairtree_root/te/st/test/$timestamp/test.mets.xml","copies the mets backup storage");

    my $s3_timestamp = $s3_backup->[0][0];
    ok($s3->s3_has("test.test.$s3_timestamp.zip.gpg"),"copies the zip to s3");
    ok($s3->s3_has("test.test.$s3_timestamp.mets.xml"),"copies the mets to s3");

    ok($stage->succeeded);

    ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.zip","original zip still exists");
    ok(-e "$tmpdirs->{obj_dir}/test/pairtree_root/te/st/test/test.mets.xml","original mets still exists");
  };
};

runtests unless caller;
