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
    my $volume = $self->{volume};
    
    my $download_dir = $volume->get_download_directory();
	#XXX update get_config('staging')?
    my $stage_base = get_config('staging'=>'ingest');
    
    my $objid = $volume->get_objid();
    
    my $file = sprintf("%s/$objid.tar.gz",$download_dir,$objid);
    $self->untgz_file($file,$volume->get_staging_directory(),"--strip-components 1") or return;
    
    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
