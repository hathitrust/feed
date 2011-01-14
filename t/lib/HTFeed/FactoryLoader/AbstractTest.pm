package HTFeed::FactoryLoader::AbstractTest;

use warnings;
use strict;

use base qw(HTFeed::Test::Class);
use Test::More;

sub has_children : Test(1){
    my $self = shift;
    my $t_class = $self->testing_class();
    my $child_count = keys (%{$HTFeed::FactoryLoader::subclass_map{$t_class}});    
    ok($child_count > 0, "$t_class has $child_count children");
}

1;
__END__
