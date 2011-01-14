package HTFeed::Stage::AbstractTest;

use warnings;
use strict;

use base qw(HTFeed::Test::Class);
use Test::More;
use HTFeed::Test::Support qw(get_test_volume);

sub test_isa : Test(startup => 2){
    my $self = shift;
    my $t_class = $self->testing_class();
    
    # instantiate and make sure the it isa what it should be
    my $volume = get_test_volume();
    my $obj = new_ok( $t_class => [volume => $volume] );
    isa_ok($obj, 'HTFeed::Stage', $t_class);
    
    # save the volume for later
    $self->{volume} = $volume;
}

# make a clean stage for each test method
sub setup : Test(setup){
    my $self = shift;
    my $t_class = $self->testing_class();
    my $volume = $self->{volume};
    $self->{test_stage} = eval "$t_class->new(volume => \$volume)";
}

sub stage_interface_adherance : Test(1){
    my $self = shift;
    my $test_stage = $self->{test_stage};
    
    ok(1,"It Works!");
}

1;

__END__
