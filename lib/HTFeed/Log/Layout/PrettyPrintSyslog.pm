package HTFeed::Log::Layout::PrettyPrintSyslog;

use strict;
use warnings;
use Sys::Hostname;
use POSIX qw(strftime);

# Like PrettyPrint, but prepend the time, hostname, and pid.
use HTFeed::Log::Layout::PrettyPrint;
use base qw(HTFeed::Log::Layout::PrettyPrint);

sub render {
    my $self = shift;
    my $time = strftime "%b %d %H:%M:%S", localtime;
    my $hostname = hostname;

    return "$time $hostname $0\[$$\]: " . $self->SUPER::render(@_);
}

1;

__END__;
