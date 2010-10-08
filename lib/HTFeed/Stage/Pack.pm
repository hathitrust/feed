package HTFeed::Stage::Pack;

use warnings;
use strict;

use base qw(HTFeed::Stage);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    
    # TODO: make staging/working/download dir consistant clear and implimented
    my $staging_dir = $volume->get_staging_directory();
    my $working_dir = get_config('staging_directory');

    my $cmd = sprintf("zip -q -r %s/%s.zip %s",$working_dir,$staging_dir,$objid);
    `$cmd`;

    # TODO: check, set errors
    
    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
