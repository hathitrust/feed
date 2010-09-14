package HTFeed::PackageType::IA::JPEG2000_hul;
use base qw(HTFeed::ModuleValidator::JPEG2000_hul);
use warnings;
use strict;

validate_layer_count{
    my $self = shift;
    my $layer_count = shift;
    
    if ($layer_count == 1){
        return 1;
    }
    
    $self->_set_error("invalid layer count: found $layer_count expected 1");
    
    return;
}

1;

__END__;
