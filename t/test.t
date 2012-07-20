use warnings;
use strict;

use FindBin;
use Test::Harness;

my $base = $FindBin::Bin;
my @tests;

# get tests to run...
opendir(DIR, $base) or die "Couldn't open dir $base: $!";
while (my $file = readdir(DIR)) {
	next if(! -f $file);
	next if ($file =~ /^\./);
	next if($file eq 'test.t');
	push @tests, $file;
}
closedir DIR;

# and run them
runtests @tests;
