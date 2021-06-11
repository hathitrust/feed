use Test::Spec;
use HTFeed::DBTools;
use HTFeed::DataDenZipAudit;
use HTFeed::Storage::PrefixedVersions;

use strict;

describe "HTFeed::StorageAudit" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);
  my $old_storage_classes;

  before each => sub {
    $old_storage_classes = get_config('storage_classes');
    my $new_storage_classes = {
      'prefixedversions-test' =>
      {
        class => 'HTFeed::Storage::PrefixedVersions',
        obj_dir => $tmpdirs->{obj_dir} . '/obj',
        encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
      }
    };
    set_config($new_storage_classes,'storage_classes');
  };

  after each => sub {
    set_config($old_storage_classes,'storage_classes');
  };


  sub setup_storage {
    my $volume = stage_volume($tmpdirs,@_);
    my $storage = HTFeed::Storage::PrefixedVersions->new(
      name => 'prefixedversions-test',
      volume => $volume,
      config => {
        obj_dir => $tmpdirs->{obj_dir} . '/obj',
        encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
      },
    );
    $storage->encrypt;
    $storage->stage;
    $storage->make_object_path;
    $storage->move;
    $storage->record_audit;
    return $storage;
  }

  describe "choose" => sub {
    it "succeeds" => sub {
      my $storage = setup_storage('test', 'test');
      my $vol = HTFeed::DataDenZipAudit::choose('prefixedversions-test');
      is($vol->{namespace}, 'test', 'choose returns namespace "test"');
      is($vol->{objid}, 'test', 'choose returns objid "test"');
      is($vol->{version}, $storage->{timestamp}, 'choose returns timestamp');
      is($vol->{path}, $storage->object_path(), 'choose returns object path');
    };
  };

  describe "#new" => sub {
    it "succeeds" => sub {
      my $storage = setup_storage('test', 'test');
      my $audit = HTFeed::DataDenZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               path => $storage->object_path(),
                                               storage_name => 'prefixedversions-test');
      ok($audit, 'new returns a value');
    };
  };

  describe "#run" => sub {
    it "succeeds" => sub {
      my $storage = setup_storage('test', 'test');
      my $zip_file = $storage->object_path() . '/' . 'test.zip.gpg';
      my $audit = HTFeed::DataDenZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               path => $storage->object_path(),
                                               storage_name => 'prefixedversions-test');
      my $result = $audit->run();
      is($result, 1, 'check returns 1');
    };

    it "fails when METS checksum is altered" => sub {
      my $storage = setup_storage('test', 'test');
      my $mets_file = $storage->object_path() . '/' . $storage->mets_filename();
      `sed -i s/2d40d65c1aecd857b3f780e85bc9bd92/2d40d65c1aecd857b3f780e85bc9bd91/g $mets_file`;
      my $audit = HTFeed::DataDenZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               path => $storage->object_path(),
                                               storage_name => 'prefixedversions-test');
      my $result = $audit->run();
      is($result, 0, 'check returns 0');
      my $sql = 'SELECT COUNT(*) FROM feed_audit_detail' . 
                ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
      my @res = HTFeed::DBTools::get_dbh->selectrow_array($sql, undef, 'test', 'test');
      is($res[0], 1, 'BadChecksum error recorded');
    };

    it "fails when database checksum is altered" => sub {
      my $storage = setup_storage('test', 'test');
      my $sql = 'UPDATE feed_backups SET saved_md5sum=?' .
                ' WHERE namespace=? AND id=? AND version=?';
      HTFeed::DBTools::get_dbh->prepare($sql)->execute('deadbeef' x 4,
                                                       'test', 'test',
                                                       $storage->{timestamp});
      my $audit = HTFeed::DataDenZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               path => $storage->object_path(),
                                               storage_name => 'prefixedversions-test');
      my $result = $audit->run();
      is($result, 0, 'run returns 0');
      $sql = 'SELECT COUNT(*) FROM feed_audit_detail' . 
             ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
      my @res = HTFeed::DBTools::get_dbh->selectrow_array($sql, undef, 'test', 'test');
      is($res[0], 1, 'BadChecksum error recorded');
    };
  };
};

runtests unless caller;

