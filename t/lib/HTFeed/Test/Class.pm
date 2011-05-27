package HTFeed::Test::Class;

use base qw(Test::Class);
use HTFeed::Test::Support qw(test_config);

# return testing class, with assumption that $class eq "$testing_class::Test"
sub testing_class{
    my $self = shift;
    my $class = ref $self;
    $class =~ s/::Test$//;
    return $class;
}

# return Config.pm settings to their initial state in case they have been changes
sub global_test_teardown : Test(teardown){
    HTFeed::StagingSetup::clear_stage;
    test_config('original');
}

1;

__END__
