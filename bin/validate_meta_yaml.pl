use strict;
use warnings;

use Data::Dumper;
use YAML::XS qw(LoadFile);

# Usage:
# perl validate_meta_yaml.pl meta_1.yml meta_2.yml ... meta_n.yml

# Take any number of paths from commandline,
# and attempt loading each as YAML file.
# Lack of crash means OK the file was at least well formed.
# Any validation is done at the whim of the YAML module used.

while (my $file = shift @ARGV) {
    chomp $file;
    print "Attempt loading $file...\n";
    my $yaml = "error";
    eval {
	$yaml = LoadFile($file)
    };
    if ($@) {
	print "Oops?\n$@\n";
    }
    print Dumper($yaml) . "\n";
}

