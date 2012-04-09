package HTFeed::PackageType::Yale::Unpack;

use warnings;
use strict;

use base qw(HTFeed::Stage::Unpack);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);

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

# do cleaning that is appropriate after failure
sub clean_failure{
    my $self = shift;
    $self->{volume}->clean_preingest();
}


1;

__END__
