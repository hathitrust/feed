use strict;
use warnings;

use File::Copy;
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path;

use Test::Spec;
use HTFeed::RepositoryIterator;

describe "HTFeed::RepositoryIterator" => sub {
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);
  
  sub make_sdr_entry {
    my $namespace = shift;
    my $objid = shift;

    my $pt_objid = s2ppchars($objid);
    my $pt_path = id2ppath($objid);
    my $full_path = "/tmp/sdr1/obj/$namespace/$pt_path" . $pt_objid;
    File::Path::make_path($full_path);
    `touch $full_path/$pt_objid.mets.xml`;
    `touch $full_path/$pt_objid.zip`;
  }

  before all => sub {
    my $namespace = 'test';
    my $objid = 'test';
    make_sdr_entry('ns1', 'objid1');
    make_sdr_entry('ns2', 'objid2');
  };
  
  after all => sub {
    File::Path::remove_tree('/tmp/sdr1');
  };

  describe 'new' => sub {
    it "creates an object that exposes the expected data" => sub {
      my $iterator = HTFeed::RepositoryIterator->new('/tmp/sdr1');
      is($iterator->{path}, '/tmp/sdr1', 'it has the path we gave it');
      is($iterator->{sdr_partition}, 1, 'it has sdr partition of 1 from sdr1');
    };
  };

  describe 'next_object' => sub {
    it "returns an object with the expected data" => sub {
      my $iterator = HTFeed::RepositoryIterator->new('/tmp/sdr1');
      my @objects;
      my $object = $iterator->next_object;
      is($object->{path}, '/tmp/sdr1/obj/ns1/pairtree_root/ob/ji/d1/objid1', 'path to the terminal directory');
      is($object->{namespace}, 'ns1', 'namespace `test` from path');
      is($object->{objid}, 'objid1', 'objid `objid1` from pairtree');
      is($object->{file_objid}, 'objid1', 'file_objid `objid1` from filename');
      is($object->{directory_objid}, 'objid1', 'directory_objid `objid1` from terminal directory name');
      is_deeply($object->{contents}, ['objid1.mets.xml','objid1.zip'], '.mets.xml and .zip contents');
      is($iterator->{objects_processed}, 1, 'it has processed 1 object');
      
    };

    it "returns two objects" => sub {
      my $iterator = HTFeed::RepositoryIterator->new('/tmp/sdr1');
      while ($iterator->next_object) { }
      is($iterator->{objects_processed}, 2, 'it has processed 2 objects');
    };

    describe 'with a subdirectory' => sub {
      it "returns an object with the expected data" => sub {
        my $iterator = HTFeed::RepositoryIterator->new('/tmp/sdr1/obj/ns1/');
        my @objects;
        my $object = $iterator->next_object;
        is($object->{path}, '/tmp/sdr1/obj/ns1/pairtree_root/ob/ji/d1/objid1', 'path to the terminal directory');
        is($object->{namespace}, 'ns1', 'namespace `ns1` from path');
        is($object->{objid}, 'objid1', 'objid `objid1` from pairtree');
        is($object->{file_objid}, 'objid1', 'file_objid `objid1` from filename');
        is($object->{directory_objid}, 'objid1', 'directory_objid `objid1` from terminal directory name');
        is_deeply($object->{contents}, ['objid1.mets.xml','objid1.zip'], '.mets.xml and .zip contents');
        is($iterator->{objects_processed}, 1, 'it has processed 1 file');
      };

      it "returns only one object" => sub {
        my $iterator = HTFeed::RepositoryIterator->new('/tmp/sdr1/obj/ns1/');
        while ($iterator->next_object) { }
        is($iterator->{objects_processed}, 1, 'it has processed 1 object');
      };
    };
  };
};

runtests unless caller;
