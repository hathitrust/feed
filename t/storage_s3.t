use Test::Spec;
use Test::Exception;
use HTFeed::Storage::ObjectStore;

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

};

runtests unless caller;
