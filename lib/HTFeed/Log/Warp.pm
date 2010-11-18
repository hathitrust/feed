package HTFeed::Log::Warp;

use warnings;
use strict;

# Synopsis
# $logger->("ErrorCode",field => "data",...)
sub toDBArray {
    my $error_message = HTFeed::Log::error_code_to_string(shift);
    my %message_fields = @_;

    my $error_array = HTFeed::Log::fields_hash_to_array(\%message_fields);

    return ($error_message, @$error_array);
}

1;

__END__;
