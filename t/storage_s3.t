use Test::Spec;
use Test::Exception;
use FindBin;
use lib "$FindBin::Bin/lib";
use HTFeed::Storage::ObjectStore;
use HTFeed::Test::SpecSupport;

use strict;

describe "HTFeed::Storage::S3" => sub {

  spec_helper 's3_helper.pl';

  local our ($s3, $bucket);

  describe "#list_objects" => sub {
    it "handles pagination"  => sub {
      my @files = qw(a b c d e f g);
      put_s3_files(@files);

      my @keys = map { $_->{Key} } @{$s3->list_objects('--max-items' => '2')};
      is_deeply(\@keys, \@files);
    };

    it "handles empty bucket" => sub {
      $s3->rm('/',"--recursive");
      my $result = $s3->list_objects();
      is(scalar @{$result}, 0);
    };
  };

  describe "#object_iterator" => sub {
    before each => sub {
      $s3->rm('/',"--recursive");
    };

    it "lists all objects"  => sub {
      my @files = qw(a b c);
      put_s3_files(@files);
      my $iterator = $s3->object_iterator;
      foreach my $file (@files) {
        ok(defined $iterator->());
      }
      ok(!defined $iterator->());
    };

    it "lists all objects across page boundaries"  => sub {
      $ENV{S3_ITERATOR_BATCH_SIZE} = 3;
      my @files = qw(a b c d e f);
      put_s3_files(@files);
      my $iterator = $s3->object_iterator;
      foreach my $file (@files) {
        ok(defined $iterator->());
      }
      ok(!defined $iterator->());
      delete $ENV{S3_ITERATOR_BATCH_SIZE};
    };

    it "handles empty bucket" => sub {
      my $iterator = $s3->object_iterator;
      ok(!defined $iterator->());
    };
  };
};

runtests unless caller;
