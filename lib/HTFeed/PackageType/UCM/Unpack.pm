package HTFeed::PackageType::UCM::Unpack;

use warnings;
use strict;

use base qw(HTFeed::Stage::Unpack);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);

# return estimated space needed on ramdisk
sub ram_disk_size{
    my $self = shift;
    my $volume = $self->{volume};

    # wild guess of 256M for now
    return 256*1048576;
}

sub run{
    my $self = shift;
    # make staging directories
    $self->SUPER::run();
    my $volume = $self->{volume};

    my $srcdir =  $volume->get_download_directory();
    my $destdir = get_config('staging' => 'preingest');

    # just symlink from 'download' directory to staging directory
    system("cp -rs '$srcdir/' '$destdir'") and 
        $self->set_error("OperationFailed",operation => "symlink",
            detail => "cp -s returned $?");

    $self->_set_done();
    return $self->succeeded();
}



1;

__END__
