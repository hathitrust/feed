package HTFeed_Test::Stage;

use warnings;
use strict;

use base qw(Test::Class);

use Test::Most;
require HTFeed::Volume;

sub testing_class {
    croak "override this method";
}

# this runs first
sub startup : Test(startup => 2){
    my $self = shift;
    
    my $volume = HTFeed::Volume->new(objid => '39015066056998',namespace => 'mdp',packagetype => 'google') or die ("Can't finish testing without a Volume");
    $self->{volume} = $volume;
    
    $class = testing_class();
    
    use_ok $class or return ("use $class failed");
    my $stage_obj = new_ok($class => ['volume', $volume]);
}

# this runs before each test method
sub setup : Test(setup){
    my $self = shift;
    my $class = testing_class();
    $self->{stage} = $class->new($self->{volume});
}

# this runs after each test method
sub teardown : Test(teardown){
    my $self = shift;
    $self->{stage} = undef;
}

sub new_fails_on_bad_volume : Test{
    throws_ok(
        sub {
            my $stage_obj = HTFeed::Stage::Download->new( Volume => bless(\{some => "random", data => "here"}, "Class::Foo") );
        },
        qr /cannot be constructed without an HTFeed::Volume/,
        'throw error on construction without volume object'
    );
}

sub check_failure_pass : Test{
    my $self = shift;
    my $stage_obj = $self->{stage};
    
    $stage_obj->_set_done;
    ok(! $stage_obj->failed);
}

sub check_failure_fail : Test{
    my $self = shift;
    my $stage_obj = $self->{stage};
    
    $stage_obj->_set_error("We Failed!");
    $stage_obj->_set_done;
    ok($stage_obj->failed);
}

sub check_failure_throw : Test{
    my $self = shift;
    my $stage_obj = $self->{stage};
    
    throws_ok(
        sub{
            my $failure = $stage_obj->failed();
        },
        qr //,
        'throw error on failure() if we haven\'t set done flag'
    );
}

1;

__END__
