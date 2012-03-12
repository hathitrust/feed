package HTFeed::ServerStatus;

use warnings;
use strict;

use HTFeed::Config;
use base qw(Exporter);
our @EXPORT = qw(continue_running_server);

my $stop_file = get_config('daemon'=>'stop_file');
my $locked = _locked();

if ($locked){
    print "LOCKED!\n";
    exit 1;
}

# check if stop condition is met
sub _locked {
    -e $stop_file ? return 1 : return 0;
}

=item continue_running_server
return true is exit condition in _locked() has not been met, indicating it is permissable to continue into a critical code section
=cut
sub continue_running_server {
	# once stop condition is met once, always return false
    return if($locked);
    $locked = _locked();
    return if($locked);
    return 1;
}

1;
__END__

=head1 NAME

HTFeed::ServerStatus

=head1 SYNOPSIS

 use HTFeed::ServerStatus;
 if(continue_running_server) {
     # critical code
     # esp database handle access/creation
 }
 else {
     # exit or die here
 }

=cut