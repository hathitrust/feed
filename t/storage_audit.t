use Test::Spec;
use Test::Exception;
use HTFeed::Storage::ObjectStore;
use HTFeed::StorageAudit;
use POSIX qw(strftime);

use strict;

describe "HTFeed::StorageAudit" => sub {
  spec_helper 'storage_helper.pl';
  spec_helper 's3_helper.pl';
  local our ($tmpdirs, $testlog, $bucket, $s3);

  sub stage_test_volume {
    my $tmpdirs = shift;
    my $namespace = shift;
    my $objid = shift;

    my $mets = $tmpdirs->test_home . '/fixtures/volumes/test.mets.xml';
    my $zip = $tmpdirs->test_home . '/fixtures/volumes/test.zip';
    system("cp $mets $tmpdirs->{ingest}/$objid.mets.xml");
    mkdir("$tmpdirs->{zipfile}/$objid");
    system("cp $zip $tmpdirs->{zipfile}/$objid/$objid.zip");

    my $volume = HTFeed::Volume->new(
      namespace => $namespace,
      objid => $objid,
      packagetype => 'simple');
  }

  sub object_storage {
    my $volume = stage_test_volume($tmpdirs,@_);

    my $storage = HTFeed::Storage::ObjectStore->new(
      volume => $volume,
      config => {
        bucket => $s3->{bucket},
        awscli => $s3->{awscli}
      },
    );

    return $storage;
  }

  # Add test0 and test1 to AWS
  sub setup_storage {
    $s3->rm('/',"--recursive");
    foreach my $n (0 .. 1) {
      my $storage = object_storage('test','test' . $n);
      $storage->put_object($storage->mets_key,$storage->{volume}->get_mets_path());
      $storage->put_object($storage->zip_key,$storage->zip_source);
      $storage->record_backup;
    }
  }

  # Add nonexistent test2 and test3 to DB
  sub add_db_entries {
    my $dbh = HTFeed::DBTools::get_dbh();
    my $version = strftime("%Y%m%d%H%M%S", gmtime);
    foreach my $n (2 .. 3) {
      my $stmt =
      "INSERT INTO feed_backups (namespace, id, path, version, zip_size, \
        mets_size, saved_md5sum, lastchecked, lastmd5check, md5check_ok) \
        VALUES (?,?,?,?,0,0,'00000000', \
        CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,1)";
      my $sth  = $dbh->prepare($stmt);
      $sth->execute('test', 'test' . $n, "s3://$s3->bucket/" . $n, $version);
    }
  }

  describe "#new" => sub {
    it "succeeds" => sub {
      my $audit = HTFeed::StorageAudit->new(bucket => $s3->{bucket},
                                            awscli => $s3->{awscli});
      ok($audit, 'new returns a value');
    };
  };

  describe "#run_not_in_aws_check" => sub {
    it "reports no errors" => sub {
      setup_storage();
      my $audit = HTFeed::StorageAudit->new(bucket => $s3->{bucket},
                                            awscli => $s3->{awscli});
      is($audit->run_not_in_aws_check(), 0, 'no errors reported');
    };
    
    it "reports errors when AWS objects are missing" => sub {
      setup_storage();
      add_db_entries();
      my $audit = HTFeed::StorageAudit->new(bucket => $s3->{bucket},
                                            awscli => $s3->{awscli});
      is($audit->run_not_in_aws_check(), 4, '4 errors reported');
      ok($testlog->matches(qr(test\.test2\.\d{14}\.zip)s));
      ok($testlog->matches(qr(test\.test2\.\d{14}\.mets\.xml)s));
      ok($testlog->matches(qr(test\.test3\.\d{14}\.zip)s));
      ok($testlog->matches(qr(test\.test3\.\d{14}\.mets\.xml)s));
      my $sql = 'SELECT COUNT(*) FROM feed_audit_detail WHERE namespace = ? AND (id = ? OR id = ?)';
      my @res = HTFeed::DBTools::get_dbh->selectrow_array($sql, undef, 'test', 'test2', 'test3' );
      is($res[0],4,"4 test2/test3 errors logged in feed_audit_detail");
    };
  };

  describe "#run_not_in_db_check" => sub {
    it "reports no errors" => sub {
      setup_storage();
      my $audit = HTFeed::StorageAudit->new(bucket => $s3->{bucket},
                                            awscli => $s3->{awscli});
      is($audit->run_not_in_db_check(), 0, 'no errors reported');
    };

    it "reports errors when database entries are missing" => sub {
      setup_storage();
      # Remove test1 from database, leave test0 alone.
      my $sql = 'DELETE FROM feed_backups WHERE namespace = ? AND id = ?';
      my $sth = HTFeed::DBTools::get_dbh()->prepare($sql);
      $sth->execute('test', 'test1');
      my $audit = HTFeed::StorageAudit->new(bucket => $s3->{bucket},
                                            awscli => $s3->{awscli});
      # The audit double-reports because of XML and ZIP file.
      is($audit->run_not_in_db_check(), 2, '2 errors reported');
      ok($testlog->matches(qr(test\.test1\.\d{14})s), 'errors reported for missing DB entry');
      ok($testlog->matches(qr(test\.test0\.\d{14})s), 'no errors reported for intact DB entry');
      $sql = 'SELECT COUNT(*) FROM feed_audit_detail WHERE namespace = ? AND id = ?';
      my @res = HTFeed::DBTools::get_dbh->selectrow_array($sql, undef, 'test', 'test1');
      is($res[0],2,"test1 errors logged in feed_audit_detail");
      @res = HTFeed::DBTools::get_dbh->selectrow_array($sql, undef, 'test', 'test0');
      is($res[0],0,"no test0 errors logged in feed_audit_detail");
    };
  };

  describe "#run" => sub {
    it "reports no errors" => sub {
      setup_storage();
      my $audit = HTFeed::StorageAudit->new(bucket => $s3->{bucket},
                                            awscli => $s3->{awscli});
      is($audit->run(), 0, 'no errors reported');
    };

    it "populates audit->{lastchecked}" => sub {
      setup_storage();
      my $audit = HTFeed::StorageAudit->new(bucket => $s3->{bucket},
                                            awscli => $s3->{awscli});
      $audit->run();
      ok(defined $audit->{lastchecked}, 'audit->{lastchecked} exists');
    };
  };
};

runtests unless caller;

