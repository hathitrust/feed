package HTFeed::Test::Class;

use Test::Class;
use base qw(Test::Class);
use HTFeed::Test::Support qw(test_config);
use HTFeed::Config qw(get_config);
use File::Path qw(remove_tree);

# return testing class, with assumption that $class eq "$testing_class::Test"
# or for example "$testing_class::SomethingTest"

sub testing_class{
    my $self = shift;
    my $class = ref $self;
    $class =~ s/::\w*Test$//;
    return $class;
}

sub global_test_setup : Test(setup){
    # wipe download directory
    my $download_dir = get_config('staging'=>'download');
    remove_tree $download_dir;
    mkdir $download_dir;
}

sub global_test_teardown : Test(teardown){
    # return Config.pm settings to their initial state in case they have been changes
    test_config('original');
    # wipe download directory
    my $download_dir = get_config('staging'=>'download');
    remove_tree $download_dir;
    mkdir $download_dir;
}

1;

__END__
