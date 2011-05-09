package HTFeed::Config;

use warnings;
use strict;
use YAML::Any;
use Carp;

use base qw(Exporter);
our @EXPORT = qw(get_config);
our @EXPORT_OK = qw(set_config);

my $config;

# build error message at startup in case $ENV{HTFEED_CONFIG} changes 
my $bad_path_error_message = sprintf("%s Error: %%s is not data member in your config file (%s)", __PACKAGE__, $ENV{HTFEED_CONFIG});

init();

sub init{
    # get config file
    my $config_file;
    if (defined $ENV{HTFEED_CONFIG}){
        $config_file = $ENV{HTFEED_CONFIG};
    }
    else{
        die "set HTFEED_CONFIG";
    }

    # load config file
    eval{
        $config = YAML::Any::LoadFile($config_file);
        my $premis_config = YAML::Any::LoadFile(get_config('premis_config'));
        # copy premis config to main config
        while(my ($key, $val) = each(%$premis_config)) {
            $config->{$key} = $val;
        }
    };
    if ($@){ die ("loading $config_file failed: $@"); }

    ## TODO: check file validity, can't do this until we establish what the file will look like
    ## TODO: test script to dig out all the config vars and check against config file
}

=get_config
get an entry out

# Synopsis
use HTFeed::Config qw(get_config);
get_config('database' => 'datasource');
get_config('jhove');

=cut
sub get_config{
    # drill down to the leaf
    my $cursor = $config;
    foreach my $hashlevel (@_) {
        # die if we try to traverse the tree past a leaf
        croak( sprintf($bad_path_error_message, join('=>',@_)) ) if (!ref($cursor));
        $cursor = $cursor->{$hashlevel};
        
        # die if we try to traverse the tree where no path exists
        croak( sprintf($bad_path_error_message, join('=>',@_)) ) if (not defined $cursor);
    }
    return $cursor;
}

=set_config
change an entry after config is loaded
this probably shouldn't be used in production, but will be quite helpful in test scripts

change_config('setting','path'=>'to'=>'my'=>'setting')
=cut
sub set_config{
    my $setting = shift;
    my $leaf = pop;
    my $cursor = $config;
    foreach my $hashlevel (@_) {
        $cursor = $cursor->{$hashlevel};
        croak( sprintf("$bad_path_error_message", join('=>',@_,$leaf)) ) if (! ref($cursor));
    }
    $cursor->{$leaf} = $setting;
    return 1;
}

1;

__END__
