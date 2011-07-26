package HTFeed::PackageType::MPubDCU::UtahState;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MPubDCU::UMP);

our $identifier = 'utahstate';

our $config = {
    %{$HTFeed::PackageType::MPubDCU::UMP::config},
    description => 'Utah State University Press',
    capture_agent => 'MPublishing',
    
    # utah state missing checksums
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

This is the package type configuration file for Utah State Press materials

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('utahstate');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2011 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
