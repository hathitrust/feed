package HTFeed::Test::Class;

use base qw(Test::Class);

# return testing class, with assumption that $class eq "$testing_class::Test"
sub testing_class{
    my $self = shift;
    my $class = ref $self;
    $class =~ s/::Test$//;
    return $class;
}

1;

__END__
