package HTFeed::TestVolume;

use warnings;
use strict;

use base qw(HTFeed::Volume);

=description
    HTFeed::TestVolume is a subclass of volume to support scripts (feed/bin)
    that run on non-packaged data, only the functions needed to that end are
    implimented, more will be added as needed.
=cut

sub new{
    my $class = shift;

    my $self = {
        namespace => undef,
        packagetype => undef,
        dir => undef,
        # '' for the objid will make the file names in the image metadata pass validation
        objid => q{},
        @_,
    };
    
    $self->{nspkg} = new HTFeed::Namespace($self->{namespace},$self->{packagetype});
    
    bless($self, $class);
    return $self;
}

sub get_staging_directory {
    my $self = shift;
    return $self->{dir};
}

1;

__END__
