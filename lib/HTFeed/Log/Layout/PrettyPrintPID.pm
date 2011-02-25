package HTFeed::Log::Layout::PrettyPrintPID;

use strict;
use warnings;

# Like PrettyPrint, but prepend the process ID.
use HTFeed::Log::Layout::PrettyPrint;
use base qw(HTFeed::Log::Layout::PrettyPrint);


sub render {
    my $self = shift;

    return "$$: " . $self->SUPER::render(@_);
}

1;

__END__;
