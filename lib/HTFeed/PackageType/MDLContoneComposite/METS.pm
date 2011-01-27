#!/usr/bin/perl

package HTFeed::PackageType::MDLContoneComposite::METS;
use HTFeed::PackageType::MDLContone::METS;
use HTFeed::METSFromSource;
# get the default behavior from HTFeed::METSFromSource
use base qw(HTFeed::METSFromSource);

# override the default add_dmdsecs with the one from MDLContone::METS;

sub _add_dmdsecs {
    return HTFeed::PackageType::MDLContone::METS::_add_dmdsecs(@_);
}

1;
