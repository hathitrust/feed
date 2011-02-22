package HTFeed::PackageType::MPub::MPubUMP;
use HTFeed::PackageType::MPub;
use base qw(HTFeed::PackageType::MPub);
use strict;

our $identifier = 'mpub_ump';

our $config = {
	%{$HTFeed::PackageType::MPub::config},
    volume_module => 'HTFeed::Volume',
    
    # Regular expression that distinguishes valid files in the file package
    valid_file_pattern => qr/^( 
		checksum\.md5 |
		pageview\.dat |
		\w+\.(xml|pdf) |
		\d{8}.(html|jp2|tif|txt)
		)/x,
};

__END__

=pod

This is the package type configuration file for MPub materials (UM Press)

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('mpub');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
