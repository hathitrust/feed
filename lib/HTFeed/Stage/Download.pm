package HTFeed::Stage::Download;

use warnings;
use strict;
use LWP::UserAgent;

use base qw(HTFeed::Stage);

use Log::Log4perl qw(get_logger);

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
    return 1 if -e "$path/$filename";

    my $ua = LWP::UserAgent->new;
    $ua->agent('HTFeedBot/0.1 '); # space causes LWP to append its ua

    get_logger()->trace("Requesting $url");
    my $request = HTTP::Request->new('GET', $url);
    my $response = $ua->request($request, $pathname);

    if( $response->is_success() ){
        my $size = (-s $pathname);
        my $expected_size = $response->header('content-length');
        if (not defined $expected_size or $size eq $expected_size){
            get_logger()->trace("Downloading $url succeeded, $size bytes downloaded");
            return 1;
        }
        else{
            $self->set_error("OperationFailed",file=>$filename,operation=>'download',detail => "size of $filename does not match HTTP header: actual $size, expected $expected_size");
            return 0;
        }
    }
    elsif($not_found_ok and $response->code() eq 404){
        get_logger()->trace("$url not found");
        return 0;
    }
    else{
        $self->set_error("OperationFailed",file => $filename,operation=>'download',detail => $response->status_line);
        return 0;
    }
}

sub stage_info{
    return {success_state => 'downloaded', failure_state => 'ready'};
}

# do cleaning that is appropriate after failure
sub clean_failure{
    my $self = shift;
    $self->{volume}->clean_download();
}

1;

__END__
