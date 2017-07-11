package HTFeed::Stage::Download;

use warnings;
use strict;
use LWP::UserAgent;
use HTFeed::Version;
use Date::Manip;

use base qw(HTFeed::Stage);

use Log::Log4perl qw(get_logger);

=head1 NAME

HTFeed::Stage::Download

=item DESCRIPTIONS

Base class for HTFeed Download stage
Manages download of material to ingest from remote location

=cut

=item download()

$self->download(url => $url, path => $path, filename => $filename, not_found_ok => 1);
downloads file at $url to $path/$filename
not_found_of suppresses errors on 404, defaults to false

=cut

sub download{
    my $self = shift;
    my $arguments = {
        url => undef,
        path => undef,
        filename => undef,
        cookies => undef,
        not_found_ok => 0,
        @_,
    };
    my $url = $arguments->{url};
    my $path = $arguments->{path};
    my $filename = $arguments->{filename};
    my $not_found_ok = $arguments->{not_found_ok};
    my $cookies = $arguments->{cookies};

    my $pathname = "$path/$filename";
    # already downloaded? just return
    return 1 if -e "$path/$filename";

    my $ua = LWP::UserAgent->new;
    if($cookies) {
      $ua->cookie_jar($cookies);
    }
    my $version = HTFeed::Version::get_vstring();
    $ua->agent('HTFeedBot/$version  '); # space causes LWP to append its ua

    $ua = $self->authorize_user_agent($ua);

    get_logger()->trace("Requesting $url");
    my $request = HTTP::Request->new('GET', $url);
    my $response = $ua->request($request, $pathname);

    if( $response->is_success() ){
        my $size = (-s $pathname);
        my $date = $response->header('last-modified');
        utime(time,UnixDate(ParseDate($date),"%s"),$pathname);
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
        get_logger()->trace("OperationFailed",file=>$filename,operation=>'download',detail => $response->status_line);
        return 0;
    }
    else{
        $self->set_error("OperationFailed",file => $filename,operation=>'download',detail => $response->status_line);
        return 0;
    }
}

=item stage_info()

Returns stage outcome based on success/failure

=cut

sub stage_info{
    return {success_state => 'downloaded', failure_state => 'ready'};
}

=item clean_failure()

Do cleaning that is appropriate after failure

=cut

sub clean_failure{
    my $self = shift;
    $self->{volume}->clean_download();
}


=item authorize_user_agent()

Authorizes a user agent for the request. Subclasses can download this to implement
OAuth or cookie-based authentication.

=cut

sub authorize_user_agent {
  my $self = shift;
  my $ua = shift;

  return $ua;
}

1;

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
