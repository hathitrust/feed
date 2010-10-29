package HTFeed::Stage::Handle;

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
    my $url = 'http://babel.hathitrust.org/cgi/pt?id=mdp.39015033404503';
    
    my $handle = HDL::Handle->new($handle_name);
    $handle->add_value('root_admin');
    $handle->add_value($ns_admin);
    $handle->add_url($URL);
    
    my $server = HDL::Server->get();
    if ( $server->exists($handle_name) ){
        $server->delete($handle_name);
    }
    $server->put($handle);
    
    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
