package HTFeed::PackageType::SimpleDigital::METS;
use strict;
use warnings;

use base qw(HTFeed::METS);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        @_,
    );
    $self->{required_events} = ["creation","message digest calculation","fixity check","validation","ingestion"];

    return $self;
}

1;
