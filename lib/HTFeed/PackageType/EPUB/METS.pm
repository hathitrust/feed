#!/usr/bin/perl

package HTFeed::PackageType::EPUB::METS;
use strict;
use warnings;
use HTFeed::METSFromSource;
use base qw(HTFeed::METSFromSource);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        @_,
    );
    $self->{profile} = "http://www.hathitrust.org/documents/hathitrust-epub-mets-profile1.0.xml";
    $self->{required_events} = ["creation","message digest calculation","fixity check","validation","ingestion"];

    return $self;
}

1;
