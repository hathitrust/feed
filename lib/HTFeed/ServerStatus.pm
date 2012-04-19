package HTFeed::ServerStatus;

use warnings;
use strict;

use HTFeed::Config;
use Filesys::Df;

use base qw(Exporter);
our @EXPORT_OK = qw(continue_running_server check_disk_usage);

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

sub continue_running_server {
	# once stop condition is met once, always return false
    return if($locked);
    $locked = _locked();
    return if($locked);
    return 1;
}

sub check_disk_usage {
    my $pctused = df(get_config('staging_root'))->{per};
    if( $pctused > get_config('staging_root_usage_limit') ) {
        die("RAM disk is $pctused% full!\n");
    }
	return;
}

1;
__END__

=head1 NAME

HTFeed::ServerStatus - Feed server management 

=head1 SYNOPSIS

HTFeed::ServerStatus contains methods to control basic server functions

=head1 DESCRIPTION

 use HTFeed::ServerStatus;
 if(continue_running_server) {
     # critical code
     # esp database handle access/creation
 }
 else {
     # exit or die here
 }

=head2 METHODS

=over 4

=item continue_running_server()

Return true is exit condition in _locked() has not been met,
indicating it is permissable to continue into a critical code section

=item check_disk_usage()

Die if staging area is overfilled

=back

=head1 AUTHOR

=head1 COPYRIGHT

=cut
