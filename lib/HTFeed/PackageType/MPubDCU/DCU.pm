package HTFeed::PackageType::MPubDCU::DCU;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MPubDCU);

#base case for DCU (DigOnDemand)

our $identifier = 'dcu';

our $config = {
    %{$HTFeed::PackageType::MPubDCU::config},
    description => 'Digitize on Demand',

    capture_agent => 'Digital Conversion Unit',

	# no checksums
    validation_run_stages => [
        qw(validate_file_names
          validate_filegroups_nonempty
          validate_consistency
          validate_utf8
          validate_metadata)
    ],

};



__END__

=pod

This is the main package type configuration for DCU projects (DigOnDemand)

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
