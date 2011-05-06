package HTFeed::PackageType::Yale::Unpack;

use warnings;
use strict;

use base qw(HTFeed::Stage::Unpack);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);

# return estimated space needed on ramdisk
sub ram_disk_size{
    my $self = shift;
    my $volume = $self->{volume};

    # zip file may be compressed by a relatively significant factor. Be conservative in space usage.
    my $multiplier = 3.10;

    return HTFeed::Stage::estimate_space($volume->get_download_location(), $multiplier);
}

sub run{
    my $self = shift;
    # make staging directories
    $self->SUPER::run();
    my $volume = $self->{volume};

    $self->unzip_file($volume->get_download_location(),get_config('staging' => 'preingest'));

    $self->_set_done();
    return $self->succeeded();
}

# override parent class method not to junk paths and to force lowercasing of all filenames
sub unzip_file {
    return HTFeed::Stage::Unpack::_extract_file(q(yes 'n' | unzip -LL -o -q '%s' -d '%s' %s 2>&1),@_);
}


1;

__END__
