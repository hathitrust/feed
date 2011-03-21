package HTFeed::PackageType::MPubDCU::FacReprint;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MPubDCU);

#base case for MPubDCU materials (Faculty Reprints)

our $identifier = 'faculty_reprints';

our $config = {
    %{$HTFeed::PackageType::MPubDCU::config},
    description => 'Faculty Reprints',
};

__END__

=pod

This is the package type configuration file for base case MPubDCU materials
Specifically Faculty Reprints

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('faculty_reprints');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
