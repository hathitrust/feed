package HTFeed::Log::Layout::PrettyPrint;

use strict;
use warnings;
use Log::Log4perl;
use Log::Log4perl::Level;

# A Log::Log4perl::Layout
# requires log4perl.appender.app_name.warp_message = 0

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
    
    my $error_message;

    # transform ("ErrorCode",field => "data",...) if $message has 2+ fields
    if ($#$message){    
        $error_message = HTFeed::Log::error_code_to_string(shift @$message);

        while(@$message) {
            my $key = shift (@$message);
            my $val = shift (@$message);
            if(not defined $val) {
                $val = '(null)';
            } 
            if($val eq '') {
                $val = "(empty)";
            }
            $error_message .= "\t$key: $val";
        }
    
    }
    # just print the message as is
    else{
        $error_message = shift @$message;
    }
    
    return "$priority - $error_message\n";
}

1;

__END__;
