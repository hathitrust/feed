package HTFeed::Priority;

=description
    Priority.pm sets priorities on queued items (used by Run and feedd)
    
    priority is a positive binary int, bits are as follows
    
    XHBBBBBBBBBBXHPPPPPPPPPPPPPPPPPP
    X restricted, should always be 0
    H Higest priority, set to ingest immediately
    G Group, volumes given a group based upon arbitrary rulesets
    X reserved, should be 0
    H Highest priority in Group
    P Priority, within group based upon age
=cut

use warnings;
use strict;
use Carp;

use constant {
                     # XHGGGGGGGGGGXHPPPPPPPPPPPPPPPPPP
    BEFORE_ALL      =>  1000000000000000000000000000000b,
    BEFORE_GROUP    =>              1000000000000000000b,
    AGE_MAX         =>               111111111111111111b,
    GROUP_MAX       =>                       1111111111b,
    GROUP_MOD       =>            100000000000000000000b,
}        

sub first{
    my $volume = shift;
    croak ""
}

sub first_in_group{
    
}

sub priority{
    
}

#sub reprioritize{
#    
#}

1;
