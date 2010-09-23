package HTFeed::Log::Layout::PrettyPrint;

use strict;
use warnings;
use Data::Dumper;
use Log::Log4perl::Level;

#no strict qw(refs);
use base qw(Log::Log4perl::Layout);

sub new {
    my $class = shift;
    $class = ref ($class) || $class;

    my $self = {
        format      => undef,
        info_needed => {},
        stack       => [],
    };

    bless $self, $class;

    return $self;
}

sub render {
    my($self, $message, $category, $priority, $caller_level) = @_;
    
    my $error_message = shift @$message;
    $Data::Dumper::Indent = 1;
    $error_message .= Dumper({@$message});
    
    return "$priority - $error_message\n";
}


1;

__END__;
