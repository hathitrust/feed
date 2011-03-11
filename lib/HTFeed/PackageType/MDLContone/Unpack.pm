package HTFeed::PackageType::MDLContone::Unpack;

use warnings;
use strict;
use IO::Handle;
use IO::File;
use GnuPG::Interface;

use base qw(HTFeed::Stage::Unpack);

use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

sub run{
    my $self = shift;
    # make staging directories
    $self->SUPER::run();
    my $volume = $self->{volume};
    
   
    $self->untgz_file($volume->get_download_location(),
         $volume->get_staging_directory(),"--strip-components 1") or return;
    
    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
