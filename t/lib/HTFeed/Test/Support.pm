package HTFeed::Test::Support;

use warnings;
use strict;

use base qw(Exporter);
our @EXPORT_OK = qw(get_test_volume);

# get_test_volume
# returns a valid volume object
## TODO: add options for ns, packagetype
## TODO: get pt, ns, objid from a config file
sub get_test_volume{
    return HTFeed::Volume->new(objid => '39015066056998',namespace => 'mdp',packagetype => 'google');
}

1;

__END__
