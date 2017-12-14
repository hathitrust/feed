#!/usr/bin/perl

package HTFeed::PackageType::EPUB::METS;
use strict;
use warnings;
use HTFeed::PackageType::SimpleDigital::METS;
use base qw(HTFeed::PackageType::SimpleDigital::METS);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        @_,
    );
    $self->{profile} = "http://www.hathitrust.org/documents/hathitrust-epub-mets-profile1.0.xml";

    return $self;
}

1;
