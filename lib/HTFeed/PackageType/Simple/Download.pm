package HTFeed::PackageType::Simple::Download;

use warnings;
use strict;
use base qw(HTFeed::Stage::Download);
use HTFeed::Config qw(get_config);
use HTFeed::Rclone;
use Log::Log4perl qw(get_logger);

sub run {
    my $self = shift;

    my $volume = $self->{volume};
    # check if the item already exists at $volume->get_sip_location()
    my $sip_loc = $volume->get_sip_location();
    if (-f $sip_loc) {
	get_logger->trace("$sip_loc already exists");
    } else {
	$self->download($volume);
    }
    $self->_set_done();
    return $self->succeeded();
}

sub download {
    my $self   = shift;
    my $volume = shift;

    my $url;

    if (!get_config('use_dropbox')) {
	$self->set_error(
	    'MissingFile',
	    file   => $volume->get_sip_location(),
	    detail => "Dropbox download disabled and file not found"
	);
	return;
    }

    eval {
	$url = $volume->dropbox_url;
    };
    if ($@) {
	$self->set_error(
	    'MissingFile',
	    file   => $volume->get_sip_location(),
	    detail => $@
	);
	return;
    }
    my $sip_directory = sprintf(
        "%s/%s",
        $volume->get_sip_directory(),
        $volume->get_namespace()
    );
    if (not -d $sip_directory) {
	get_logger->trace("Creating download directory $sip_directory");
	mkdir($sip_directory, 0770) or
	$self->set_error(
	    'OperationFailed',
	    operation => 'mkdir',
	    detail    => "$sip_directory could not be created"
	);
    }

    eval {
	my $rclone = HTFeed::Rclone->new;
	$rclone->copy($url, $sip_directory);
	my $download_size = $self->{job_metrics}->dir_size($sip_directory);
	$self->{job_metrics}->add("ingest_download_bytes_r_total", $download_size);
    };
    if ($@) {
	$self->set_error('OperationFailed', detail => $@);
    }
}

1;
