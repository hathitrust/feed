package HTFeed::Test::Support;

use warnings;
use strict;
use Carp;

=info
    Support for unit test
=cut

our $log_file;

## TODO: more perl, less bash, more robust
sub newLogFile{
    my $fname;
    if ($log_file){
        croak "I already made a log file!";
    }
    else{
        $fname = '/tmp/' . int(rand(10000000)) . '.log';
        `touch $fname`;
        $log_file = $fname;
    }

    return $fname;
}

sub getLogFile{
    if ($log_file){
        return $log_file
    }
    else{
        croak "I haven't made a log file!";
    }
}

#sub _clearLogFile{
#    `rm $log_file; touch $log_file`;
#    return;
#}

sub deleteLogFile{
    `rm $log_file`;
    $log_file = "";
    return;
}

1;
__END__
