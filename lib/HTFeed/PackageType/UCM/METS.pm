#!/usr/bin/perl

package HTFeed::PackageType::UCM::METS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::METS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use Image::ExifTool;
use base qw(HTFeed::METS);


sub _add_dmdsecs {
    # no descriptive metadata sections to add
    my $self = shift;

    return;
}

1;
