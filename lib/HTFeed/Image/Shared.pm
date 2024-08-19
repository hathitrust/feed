package HTFeed::Image::Shared;

# Shared functionality for the classes under HTFeed::Image.

use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl qw(get_logger);

# Take a hashref,
# check that all values are defined and truthy,
# or use key to tell you which value was invalid.
sub check_set {
    my $validate = shift || {};

    foreach my $key (keys %$validate) {
        my $val = $validate->{$key};
        if (!defined $val || !$val) {
            get_logger()->warn("Invalid input for $key in " . Dumper($validate));
            return _invalid_input($key, $val);
        }
    }

    return 1;
}

# Explain why something is invalid: is it undefined or just plain empty?
sub _invalid_input {
    my $input_name  = shift;
    my $input_value = shift;

    my $is_undef    = !defined $input_value;

    if ($is_undef) {
        get_logger()->warn("input $input_name is undefined");
    } else {
        get_logger()->warn("input $input_name is empty!");
    }

    return 0;
}

1;
