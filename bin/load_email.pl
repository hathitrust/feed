#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Log { root_logger => 'DEBUG, screen' };
use HTFeed::RunLite qw(runlite);
use METS;
use HTFeed::METS;

# process a single Bentley barcode

my $id = shift;
unless($id) {
	print "Please specify a barcode\n";
	exit;
}

my $volumes = [['bhl', $id]];

runlite(
	volumes		=> $volumes,
	namespace	=> 'bhl',
	packagetype	=> 'email',
	verbose		=> 1
);

__END__

