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
    my $volume = $self->{volume};

    my $download_dir = $volume->get_download_directory();
    my $preingest_dir = $volume->get_preingest_directory();
    my $objid = $volume->get_objid();
    my $ia_id = $volume->get_ia_id();


    my $file = sprintf('%s/%s_jp2.zip',$download_dir,$ia_id);
    # create preingest directory or symlink ram -> disk if needed
    $volume->mk_preingest_directory($self->stage_on_disk());
    $self->unzip_file($file,$preingest_dir);

    $self->_set_done();
    return $self->succeeded();
}


1;

__END__
