package HTFeed::PackageType::DLXS::Volume;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MPubDCU::Volume);
use HTFeed::Config;

# no source METS expected for this content 

sub get_source_mets_xpc {
    return;
}

sub get_source_mets_file {
    return;
}

# don't pt-escape the directory name for preingest for these (following dlxs conventions)
sub get_preingest_directory {
    my $self = shift;
    my $ondisk = shift;

    my $objid = $self->get_objid();
    return sprintf("%s/%s", get_config('staging'=>'disk'=>'preingest'), $objid) if $ondisk;
    return sprintf("%s/%s", get_config('staging'=>'preingest'), $objid);
}

1;


__END__
