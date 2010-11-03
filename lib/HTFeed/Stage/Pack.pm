package HTFeed::Stage::Pack;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    
    my $working_dir = get_config('staging'=>'memory');
    
    chdir($working_dir);
    my $cmd = sprintf("zip -q -r %s.zip %s",$objid,$objid);
    `$cmd`;

    # TODO: check, set errors
    
    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
