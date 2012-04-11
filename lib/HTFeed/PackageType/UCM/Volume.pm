package HTFeed::PackageType::UCM::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::Config;

sub get_download_directory {
    my $self = shift;
    my $objid = $self->get_objid();
    my $path = get_config('staging'=>'download');
    return "$path/$objid";
}

sub get_preingest_directory {
    my $self = shift;

    my $objid = $self->get_objid();
    return sprintf("%s/%s", get_config('staging'=>'preingest'), $objid);
}

sub get_download_location {
    my $self = shift;
    # UCM comes to us unpacked
    return $self->get_download_directory();
}

1;

__END__
