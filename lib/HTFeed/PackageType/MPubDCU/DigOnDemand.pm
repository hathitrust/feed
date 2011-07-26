package HTFeed::PackageType::MPubDCU::DigOnDemand;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MPubDCU);

#base case for MPubDCU DigOnDemand

our $identifier = 'DigOnDemand';

our $config = {
    %{$HTFeed::PackageType::MPubDCU::config},
    description => 'Digitize on Demand',

    capture_agent => 'Digital Conversion Unit',
};

__END__

=pod

This is the package type configuration file for base case MPubDCU materials
Specifically DigOnDemand

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('DigOnDemand');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
