package HTFeed::Stage::Collate::Test;

use warnings;
use strict;

use base qw(HTFeed::Stage::AbstractTest);
use Test::More;
use HTFeed::Stage::Collate;

sub my_test : Test(1){
    my $self = shift;
    ok(1);
}

1;

__END__
