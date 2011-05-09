package HTFeed::PackageType::MPubDCU::UMP;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MPubDCU);

#base case for MPubDCU (UM Press)

our $identifier = 'ump2ht';

our $config = {
    %{$HTFeed::PackageType::MPubDCU::config},
    description => 'University of Michigan Press',
    
    # Regular expression that distinguishes valid files in the file package
    # UM Press material may include a PDF. TBD how to represent this.
    valid_file_pattern => qr/^( 
		checksum\.md5 |
		pageview\.dat |
		\w+\.(xml) |
		\w+\.(pdf) |
		\d{8}.(html|jp2|tif|txt)
		)/x,

};

__END__

=pod

This is the package type configuration file for base case MPubDCU materials
Specifically UM Press

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('ump2ht');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
