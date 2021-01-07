package AWS;
# Stub package that returns fixed data structures without
# the aws binary and/or AWS credentials needing to be installed.

use warnings;
use strict;
use HTFeed::Test::TempDirs;
use File::Copy;
use File::Basename;

use base qw( Exporter );
our @EXPORT_OK = qw( list_objects get_object );

my $tmpdirs = HTFeed::Test::TempDirs->new();

# Test paging support by returning frame_test.zip and frame_test.xml on the first page,
# then returning frame_test_2.txt on the second page.
sub list_objects {
  my ($bucket, $last_id) = @_;

  if (!defined $last_id) {
    return {
             'Contents' =>
             [
               {
                 'Key' => 'frame_test.zip',
                 'LastModified' => '2020-10-25T03:55:46+00:00',
                 'ETag' => '"edf625d29070896753b8002c996e5041"',
                 'Size' => 1569354,
                 'StorageClass' => 'STANDARD'
               },
               {
                 'Key' => 'frame_test.xml',
                 'LastModified' => '2020-10-25T03:55:46+00:00',
                 'ETag' => '"3750f1688bd60256b96ff7670dc5a7fd"',
                 'Size' => 4217,
                 'StorageClass' => 'STANDARD'
               }
             ]
           };
  }
  elsif ($last_id eq 'frame_test.xml') {
    return {
             'Contents' =>
             [
               {
                 'Key' => 'frame_test_2.txt',
                 'LastModified' => '2020-10-25T03:55:46+00:00',
                 'ETag' => '"3750f1688bd60256b96ff7670dc5a7fe"',
                 'Size' => 4,
                 'StorageClass' => 'STANDARD'
               }
             ]
           };
  }
  return;
}

sub get_object {
  my ($bucket, $key, $dest) = @_;

  if ($key eq 'frame_test.zip') {
    my $src = $tmpdirs->test_home . '/fixtures/volumes/test.zip';
    File::Copy::copy($src, $dest) or die "Copy $src -> $dest failed: $!";
  }
  elsif ($key eq 'frame_test.xml') {
    my $src = $tmpdirs->test_home . '/fixtures/frame/frame_test.xml';
    File::Copy::copy($src, $dest) or die "Copy $src -> $dest failed: $!";
  }
  elsif ($key eq 'frame_test_2.txt') {
    my $cmd = "echo 'TEST' > $dest";
    `$cmd`;
    die "ERROR calling $cmd: $?" if $?;
  }
  else {
    die "AWS::get_object: unknown object key $key\n";
  }
}

1;
