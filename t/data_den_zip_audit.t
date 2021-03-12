use Test::Spec;
use HTFeed::DBTools;
use HTFeed::DataDenZipAudit;

use strict;

describe "HTFeed::StorageAudit" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);

  sub setup_storage {
    my $volume = stage_volume($tmpdirs,@_);
    my $storage = HTFeed::Storage::VersionedPairtree->new(
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
      my $vol = HTFeed::DataDenZipAudit::choose($storage->{config}{obj_dir});
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
                                               path => $storage->object_path());
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
                                               storage => $storage);
      my $result = $audit->run();
      is($result, 1, 'check returns 1');
    };

    it "fails when METS checksum is altered" => sub {
      my $storage = setup_storage('test', 'test');
      my $mets_file = $storage->object_path() . '/' . 'test.mets.xml';
      `sed -i s/2d40d65c1aecd857b3f780e85bc9bd92/2d40d65c1aecd857b3f780e85bc9bd91/g $mets_file`;
      my $audit = HTFeed::DataDenZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               path => $storage->object_path(),
                                               storage => $storage);
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
                                               storage => $storage);
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

