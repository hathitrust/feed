package HTFeed::PackageType::MPubDCU::UMP;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MPubDCU);

# base case for UM Press
# faculty_reprints, ump2ht, speccoll, utah state university

our $identifier = 'ump';

our $config = {
    %{$HTFeed::PackageType::MPubDCU::config},
    description => 'University of Michigan Press',
    capture_agent => 'MPublishing',
    
    # Validation overrides - make/model not expected
    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            'camera'               => undef,
        }
    },

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

This is the package type configuration file for UM Press material
specifically faculty_reprints, ump2ht, speccoll, utah state university

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
