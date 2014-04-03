package HTFeed::PackageType::Simple::Unpack;

use strict;
use warnings;
use base qw(HTFeed::Stage::Unpack);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use File::Find;

sub run {
	my $self = shift;
    $self->SUPER::run();


	my $volume = $self->{volume};
	my $packagetype = $volume->get_packagetype();
	my $pt_objid = $volume->get_pt_objid();

	my $download_dir = get_config('staging'=>'download');

	my $source = undef;

	my $dest = $volume->get_preingest_directory();

    my $file = sprintf('%s/%s.zip',$download_dir,$pt_objid);
    if(-e $file) {
        $self->unzip_file($file,$dest);
        $self->_set_done();
    } else {
        $self->set_error("MissingFile",file=>$file);
    }

    # move all ocr/hocr files to staging directory
    my $staging = $volume->get_staging_directory();

	return $self->succeeded();
}

1;

