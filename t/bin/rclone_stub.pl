#!/usr/bin/perl
# Brain-dead fake rclone that just copies files.

use warnings;
use strict;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";

use File::Copy;
use File::Basename;
use Getopt::Long;

die "expected arguments to rclone command" if scalar @ARGV == 0;
my $subcommand = shift @ARGV;

my $opt_config = '';
my $opt_dry_run;
Getopt::Long::GetOptions('dry-run' => \$opt_dry_run,
                         'config=s' => \$opt_config) or die "error parsing rclone options";

die "rclone --config file not found" unless -e $opt_config;

if ($subcommand eq 'copy') {
  # Copy a canned fixture, ignoring the source URL.
  my $src = "$FindBin::Bin/../fixtures/volumes/test.zip";
  my $dest = $ARGV[-1];
  die "destination $dest is not a directory" unless -d $dest;

  my $target_file = File::Basename::basename($ARGV[-2]);
  $dest .= "/$target_file";
  if (!$opt_dry_run) {
    File::Copy::copy($src, $dest) or die "rclone copy $src -> $dest failed: $!";
  }
} elsif ($subcommand eq 'delete') {
  die 'single parameter expected for delete command' unless scalar @ARGV == 1;

  my $dest = $ARGV[-1];
} else {
  die "unknown rclone subcommand '$subcommand'";
}
