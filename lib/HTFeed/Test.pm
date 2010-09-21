package HTFeed::Test;

use warnings;
use strict;
use Carp;

=info
    Support for unit test
=cut

our $logFile;

## TODO: more perl, less bash, more robust
sub getLogFile{
    my $fname;
    if ($logFile){
        $fname = $logFile;
        _clearLogFile();
    }
    else{
        $fname = '/tmp/' . int(rand(10000000)) . '.log';
        `touch $fname`;
        $logFile = $fname;
    }

    return $fname;
}

sub _clearLogFile{
    `rm $logFile; touch $logFile`;
    return;
}

sub deleteLogFile{
    `rm $logFile`;
    $logFile = "";
    return;
}

1;
__END__
