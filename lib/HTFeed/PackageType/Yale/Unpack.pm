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

    my $multiplier = 2.10;

    return HTFeed::Stage::estimate_space($volume->get_download_location(), $multiplier);
}

sub run{
    my $self = shift;
    my $volume = $self->{volume};

    # not getting preingest path from volume -- zip file contains extra paths we don't want to junk
    # create preingest directory or symlink ram -> disk if needed
    $volume->mk_preingest_directory($self->stage_on_disk());
    $self->unzip_file($volume->get_download_location(),get_config('staging' => 'preingest'));

    $self->_set_done();
    return $self->succeeded();
}

# override parent class method not to junk paths
sub unzip_file {
    return HTFeed::Stage::Unpack::_extract_file(q(yes 'n' | unzip -o -q '%s' -d '%s' %s 2>&1),@_);
}


1;

__END__
