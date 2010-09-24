package HTFeed::Log::Layout::PrettyPrint;

use strict;
use warnings;
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
        $error_message = HTFeed::Log->error_code_to_string(shift @$message);
        my %message_fields = @$message;
    
        my $error_array = HTFeed::Log->fields_hash_to_array(\%message_fields);
    
        foreach (@$error_array){
            $error_message .= "\t$_";
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
