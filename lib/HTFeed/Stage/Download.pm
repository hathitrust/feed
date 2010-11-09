package HTFeed::Stage::Download;

use warnings;
use strict;
use LWP::UserAgent;

use base qw(HTFeed::Stage);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

# $self->download(url => $url, path => $path, filename => $filename, not_found_ok => 1);
# downloads file at $url to $path/$filename
# not_found_of suppresses errors on 404, defaults to false
sub download{
    my $self = shift;
    my $arguments = {
        url => undef,
        path => undef,
        filename => undef,
        not_found_ok => 0,
        @_,
    };
    my $url = $arguments->{url};
    my $path = $arguments->{path};
    my $filename = $arguments->{filename};
    my $not_found_ok = $arguments->{not_found_ok};
    
    my $pathname = "$path/$filename";
    # already downloaded? just return
    return if -e "$path/$filename";

    my $ua = LWP::UserAgent->new;
    $ua->agent('HTFeedBot/0.1 '); # space causes LWP to append its ua
    
    my $request = HTTP::Request->new('GET', $url);
    my $response = $ua->request($request, $pathname);
    
    if( $response->is_success() ){
        my $size = (-s $pathname);
        my $expected_size = $response->header('content-length');
        if ($size eq $expected_size){
            $logger->debug("Download succeeded",volume => $self->{volume}->get_objid());
        }
        else{
            $self->_set_error("OperationFailed",file=>$filename,operation=>'download',detail => "size of $filename does not match HTTP header: actual $size, expected $expected_size");
        }
    }
    elsif($not_found_ok and $response->code() eq 404){
        $logger->debug("404 recieved on optional file: $filename",volume => $self->{volume}->get_objid());
    }
    else{
    	$self->_set_error("OperationFailed",file => $filename,operation=>'download',detail => $response->status_line);
    }

    # Try to clean up if download failed
    if($self->{failed} and -e "$path/$filename") {
	unlink($path/$filename) or $self->_set_error("OperationFailed",file=>"$path/$filename",operation=>'unlink',detail => "Error unlinking: $!");
    }
}

1;

__END__
