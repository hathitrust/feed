package HTFeed::PackageType::Feed::Unpack;

use strict;
use warnings;
use base qw(HTFeed::Stage::Unpack);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use File::Find;

# Unpacks zips created with feed generate_sip.pl

sub run {
	my $self = shift;
    $self->SUPER::run();


	my $volume = $self->{volume};
	my $packagetype = $volume->get_packagetype();
	my $objid = $volume->get_objid();

	my $download_dir = get_config('staging'=>'download');

	my $source = undef;

	my $dest = get_config('staging' => 'ingest') . "/" . $volume->get_pt_objid();

    my $file = sprintf('%s/%s.zip',$download_dir,$objid);
    if(-e $file) {
        $self->unzip_file($file,$dest);
        $self->_set_done();
    } else {
        $self->set_error("MissingFile",file=>$file);
    }

	return $self->succeeded();
}

1;
