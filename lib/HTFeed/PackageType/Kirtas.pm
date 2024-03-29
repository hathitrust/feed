package HTFeed::PackageType::Kirtas;

use HTFeed::PackageType;
use base qw(HTFeed::PackageType::Simple);
use strict;

use HTFeed::XPathValidator qw(:closures);

our $identifier = 'kirtas';

our $config = {
    %{$HTFeed::PackageType::Simple::config},
    description => 'Kirtas-digitized book material',

    # Kirtas volumes will be cached on disk
    volume_module => 'HTFeed::PackageType::Kirtas::Volume',

};

__END__

=pod

This is the package type configuration file for using the cloud validator package format and a Kirtas-generated METS for page tags.

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('kirtas');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=cut
