#!/usr/bin/perl
 
package HTFeed::PackageType::Audio::METS;
use HTFeed::METSFromSource;
# get the default behavior from HTFeed::METSFromSource
use base qw(HTFeed::METSFromSource);
 
sub _add_dmdsecs {
    return;
}

1; 
