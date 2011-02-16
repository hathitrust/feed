package HTFeed::PackageType::Yale::Unpack;

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
    my $objid = $volume->get_objid();
    my $file = sprintf('%s/%s.zip',$download_dir,$objid);

    my $multiplier = 1.10;

    return estimate_space($file, $multiplier);
}

sub run{
    my $self = shift;
    my $volume = $self->{volume};

    my $download_dir = $volume->get_download_directory();
    my $objid = $volume->get_objid();

    my $file = sprintf('%s/%s.zip',$download_dir,$objid);
    # not getting preingest path directly -- zip file contains extra paths we don't want to junk
	#XXX update get_config('staging')?
    $self->unzip_file($file,get_config('staging' => 'preingest'));

    $self->_set_done();
    return $self->succeeded();
}

# override parent class method not to junk paths
sub unzip_file {
    return HTFeed::Stage::Unpack::_extract_file(q(yes 'n' | unzip -o -q '%s' -d '%s' %s 2>&1),@_);
}


1;

__END__
