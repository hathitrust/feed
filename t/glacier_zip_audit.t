use Test::Spec;
use HTFeed::DBTools;
use HTFeed::Storage::ObjectStore;
use HTFeed::GlacierZipAudit;

use strict;

describe "HTFeed::GlacierZipAudit" => sub {
  spec_helper 'storage_helper.pl';
  spec_helper 's3_helper.pl';
  local our ($tmpdirs, $testlog);
  local our ($s3, $bucket);

  sub HTFeed::Storage::S3::restore_object {
    return 1;
  }
  
  sub HTFeed::Storage::S3::head_object {
    my $self = shift;
    my $key = shift;
    if ($ENV{S3_HEAD_OBJECT_RESTORE_PENDING}) {
      return {Restore => 'ongoing-request="true"'};
    }
    elsif ($ENV{S3_HEAD_OBJECT_RESTORE_DONE}) {
      return {Restore => 'ongoing-request="false"'};
    }
    return $self->s3api('head-object','--key',$key,@_);
  }

  sub object_storage {
    my $volume = stage_volume($tmpdirs,@_);
    
    my $storage = HTFeed::Storage::ObjectStore->new(
      volume => $volume,
      config => {
        bucket => $s3->{bucket},
        awscli => $s3->{awscli},
        encryption_key => $tmpdirs->test_home . "/fixtures/encryption_key"
      },
    );
    $storage->encrypt;
    $storage->move;
    $storage->record_backup;
    return $storage;
  }

  describe "choose" => sub {
    it "succeeds" => sub {
      my $storage = object_storage('test', 'test');
      my $vol = HTFeed::GlacierZipAudit::choose('s3://bucket');
      is($vol->{namespace}, 'test', 'choose returns namespace "test"');
      is($vol->{objid}, 'test', 'choose returns objid "test"');
      is($vol->{version}, $storage->{timestamp}, 'choose returns timestamp');
      is($vol->{path}, "s3://$bucket/" . $storage->object_path(),
         'choose returns object path');
    };
  };

  describe "pending_objects" => sub {
    it "succeeds" => sub {
      #my $storage = object_storage('test', 'test');
      my $auditable = HTFeed::GlacierZipAudit::pending_objects('s3://bucket');
      is(scalar @$auditable, 0, 'pending_objects returns zero result');
    };
  };

  describe "#new" => sub {
    it "succeeds" => sub {
      my $storage = object_storage('test', 'test');
      my $audit = HTFeed::GlacierZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               s3 => $s3, bucket => $bucket,
                                               storage => $storage);
      ok($audit, 'new returns a value');
    };
  };
  
  describe "#submit_restore_object" => sub {
    it "records restore_request for zip and METS" => sub {
      my $storage = object_storage('test', 'test');
      my $audit = HTFeed::GlacierZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               s3 => $s3, bucket => $bucket,
                                               storage => $storage);
      $audit->submit_restore_object();
      my $sql = 'SELECT COUNT(*) FROM feed_backups' . 
                ' WHERE namespace = ? AND id = ? AND version = ?' .
                ' AND restore_request IS NOT NULL';
      my @res = HTFeed::DBTools::get_dbh->selectrow_array($sql, undef,
                                                          'test', 'test',
                                                          $storage->{timestamp});
      is($res[0], 1, 'restore_request count = 1');
      my $auditable = HTFeed::GlacierZipAudit::pending_objects('s3://bucket');
      is(scalar @$auditable, 1, 'pending_objects returns positive result');
    };
  };

  describe "#run" => sub {
    it "succeeds" => sub {
      my $storage = object_storage('test', 'test');
      $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
      my $audit = HTFeed::GlacierZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               s3 => $s3, bucket => $bucket,
                                               storage => $storage);
      my $result = $audit->run();
      is($result, 1, 'succeeds');
      delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
    };

    it "removes restore_request when finished" => sub {
      my $storage = object_storage('test', 'test');
      $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
      my $audit = HTFeed::GlacierZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               s3 => $s3, bucket => $bucket,
                                               storage => $storage);
      my $result = $audit->run();
      my $sql = 'SELECT COUNT(*) FROM feed_backups' . 
                ' WHERE namespace = ? AND id = ? AND version = ?' .
                ' AND restore_request IS NOT NULL';
      my @res = HTFeed::DBTools::get_dbh->selectrow_array($sql, undef,
                                                          'test', 'test',
                                                          $storage->{timestamp});
      is($res[0], 0, 'restore_request count = 0');
      delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
    };

    it "fails when METS checksum is altered" => sub {
      my $storage = object_storage('test', 'test');
      my $audit = HTFeed::GlacierZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               s3 => $s3, bucket => $bucket,
                                               storage => $storage);
      $audit->get_files();
      `sed -i s/2d40d65c1aecd857b3f780e85bc9bd92/2d40d65c1aecd857b3f780e85bc9bd91/g $audit->{mets_path}`;
      $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
      my $result = $audit->run();
      is($result, 0, 'returns 0');
      my $sql = 'SELECT COUNT(*) FROM feed_audit_detail' . 
                ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
      my @res = HTFeed::DBTools::get_dbh->selectrow_array($sql, undef, 'test', 'test');
      is($res[0], 1, 'BadChecksum error recorded');
      delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
    };

    it "fails when database checksum is altered" => sub {
      my $storage = object_storage('test', 'test');
      my $sql = 'UPDATE feed_backups SET saved_md5sum=?' .
                ' WHERE namespace=? AND id=? AND version=?';
      HTFeed::DBTools::get_dbh->prepare($sql)->execute('deadbeef' x 4,
                                                       'test', 'test',
                                                       $storage->{timestamp});
      my $audit = HTFeed::GlacierZipAudit->new(namespace => 'test', objid => 'test',
                                               version => $storage->{timestamp},
                                               s3 => $s3, bucket => $bucket,
                                               storage => $storage);
      $ENV{S3_HEAD_OBJECT_RESTORE_DONE} = 1;
      my $result = $audit->run();
      is($result, 0, 'run returns 0');
      $sql = 'SELECT COUNT(*) FROM feed_audit_detail' . 
             ' WHERE namespace = ? AND id = ? AND status = "BadChecksum"';
      my @res = HTFeed::DBTools::get_dbh->selectrow_array($sql, undef, 'test', 'test');
      is($res[0], 1, 'BadChecksum error recorded');
      delete $ENV{S3_HEAD_OBJECT_RESTORE_DONE};
    };
  };
};

runtests unless caller;

