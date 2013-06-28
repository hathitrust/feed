#!/usr/bin/perl

package HTFeed::PackageType::MDLContone::Composite::METS;
use HTFeed::PackageType::MDLContone::METS;
use HTFeed::METSFromSource;
use HTFeed::XMLNamespaces qw(:namespaces);
# get the default behavior from HTFeed::METSFromSource
use base qw(HTFeed::METSFromSource);

# override the default add_dmdsecs with the one from MDLContone::METS;

sub _add_dmdsecs {
    return HTFeed::PackageType::MDLContone::METS::_add_dmdsecs(@_);
}

sub _add_schemas {
    my $self = shift;
    $self->SUPER::_add_schemas(@_);
    my $mets = $self->{mets};

    $mets->add_schema( "dc", NS_DC );

}

1;
