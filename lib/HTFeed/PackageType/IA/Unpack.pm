package HTFeed::PackageType::IA::Unpack;

use warnings;
use strict;

use base qw(HTFeed::Stage::Unpack);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

# return estimated space needed on ramdisk
sub ram_disk_size{
    my $self = shift;
    my $volume = $self->{volume};

    my $download_dir = $volume->get_download_directory();
    my $ia_id = $volume->get_ia_id();
    my $file = sprintf('%s/%s_jp2.zip',$download_dir,$ia_id);

    my $multiplier = 2.10;

    return HTFeed::Stage::estimate_space($file, $multiplier);
}

sub run{
    my $self = shift;
    # make staging directories
    $self->SUPER::run();
    my $volume = $self->{volume};

    my $download_dir = $volume->get_download_directory();
    my $preingest_dir = $volume->get_preingest_directory();
    my $objid = $volume->get_objid();
    my $ia_id = $volume->get_ia_id();


    my $file = sprintf('%s/%s_jp2.zip',$download_dir,$ia_id);
    $self->unzip_file($file,$preingest_dir);

    $self->_set_done();
    return $self->succeeded();
}

# do cleaning that is appropriate after failure
sub clean_failure{
    my $self = shift;
    $self->{volume}->clean_download();
}


1;

__END__
