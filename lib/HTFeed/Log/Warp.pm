package HTFeed::Log::Warp;

use warnings;
use strict;

sub toDBArray {
    # only do the transformation if we have more than one field
    # otherwise it shouldn't be needed
    if($#_){
        my $error_message = HTFeed::Log->error_code_to_string(shift);
        my %message_fields = @_;

        my $error_array = HTFeed::Log->fields_hash_to_array(\%message_fields);
    
        return [$error_message, @$error_array];
    }

    return @_;
}

1;

__END__;
