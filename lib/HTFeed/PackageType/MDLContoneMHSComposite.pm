package HTFeed::PackageType::MDLContoneMHSComposite;
use HTFeed::PackageType::MDLContoneMHS;
use base qw(HTFeed::PackageType::MDLContoneMHS);
use strict;

our $identifier = 'mdlcontone_mhsc';

our $config = {
    %{$HTFeed::PackageType::MDLContoneMHS::config},
    description => 'Minnesota Historical Society images - composite objects',

    # what stage to run given the current state
    stage_map => {
        ready      => 'HTFeed::PackageType::MDLContone::Unpack',
        unpacked   => 'HTFeed::VolumeValidator',
        validated  => 'HTFeed::Stage::Pack',
        packed     => 'HTFeed::PackageType::MDLContoneComposite::METS',
        metsed     => 'HTFeed::Stage::Handle',
        handled    => 'HTFeed::Stage::Collate',
    },

};

__END__

=pod

This is the package type configuration file for composite Minnesota Digital
Library images from the Minnesota Historical Society.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('mdlcontone_mhsc');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 201 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
