package HTFeed::Config;

use warnings;
use strict;
use YAML::XS;
use Carp;

use base qw(Exporter);
our @EXPORT_OK = qw(get_config);


my $config;

{
    # get config file
    my $config_file;
    if (defined $ENV{HTFEED_CONFIG}){
        $config_file = $ENV{HTFEED_CONFIG};
    }
    else{
        die "set HTFEED_CONFIG";
    }

    # TODO: check file validity, can't do this until we establish what the file will look like

    # load config file
    eval{
        $config = YAML::XS::LoadFile($config_file);
    };
    if ($@){ die ("loading $config_file failed: $@"); }
}

=get_config
get an entry out

# Synopsis
use HTFeed::Config qw(get_config);
get_config('database' => 'datasource');
get_config('l4p');

=cut
sub get_config{
    # get rid of package name if we have it
    {
        my ($package) = @_;
        if ($package eq __PACKAGE__){
            shift;
        }
    }
    
    # drill down to the leaf
    my $cursor = $config;
    foreach my $hashlevel (@_) {
        $cursor = $cursor->{$hashlevel};
        
        ## TODO: make this a better error message
        # die if we go down an invalid path
        croak("$hashlevel undef") if (! $cursor);
    }
    return $cursor;
}

=TODO
add map of required/allowed/overridable/non_overridable/whatever items
=cut

1;

__END__
