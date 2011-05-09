#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTFeed::DBTools::Priority qw(reprioritize);

reprioritize();

__END__

=head1 NAME

    reprioritize.pl - reorder volumes in Feedr queue based upon the priority table

=head1 TODO

automatically generate priority table

=cut