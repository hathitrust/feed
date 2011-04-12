package HTFeed::PackageType::Yale::AbstractTest;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use Test::More;
use HTFeed::Test::Support qw(get_test_volume);

sub startup : Test(startup => 3){
    my $self = shift;
    my $t_class = $self->testing_class();

    # instantiate and make sure the it isa what it should be
    my $volume = get_test_volume('yale');
    my $obj = new_ok( $t_class => [volume => $volume] );
    isa_ok($obj, 'HTFeed::Stage', $t_class);

    # basic interface adherance
    #can_ok($obj, qw(run set_error clean clean_success clean_failure clean_always clean_punt clean_unpacked_object clean_zip clean_mets clean_preingest));

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

1;

__END__


