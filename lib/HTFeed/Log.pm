package HTFeed::Log;

# Loads HTFeed log support classes and initializes logging

use warnings;
use strict;
use Carp;

use HTFeed::Log::Warp;
use HTFeed::Log::Layout::PrettyPrint;

use Log::Log4perl;

sub init{
    # check for / read environment var
    my $l4p_config;
    if (defined $ENV{HTFEED_L4P}){
        $l4p_config = $ENV{HTFEED_L4P};
    }
    else{
        croak print "set HTFEED_L4P\n";
    }

    Log::Log4perl->init($l4p_config);
    Log::Log4perl->get_logger(__PACKAGE__)->trace("l4p initialized");
    
    return;
}

1;

__END__;
