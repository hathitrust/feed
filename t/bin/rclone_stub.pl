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
  my $src = "$FindBin::Bin/../fixtures/volumes/test.zip";
  my $dest = $ARGV[-1];
  my $target_file = File::Basename::basename($ARGV[-2]);
  $dest .= "/$target_file";
  File::Copy::copy($src, $dest) or die "rclone copy $src -> $dest failed: $!";
} else {
  die "unknown rclone subcommand '$subcommand'";
}
