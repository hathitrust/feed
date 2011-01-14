package HTFeed::Stage::Unpack::Test;

use warnings;
use strict;

use base qw(HTFeed::Test::Class);
use Test::More;

sub unzip_file : Test(1){
    my $self = shift;
    ok(1);
}

sub untgz_file : Test(1){
    my $self = shift;
    ok(1);
}

1;

__END__
