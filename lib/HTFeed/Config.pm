package HTFeed::Config;

use warnings;
use strict;
use YAML::XS;
use Carp;
use File::Basename;
use File::Spec;
use Cwd qw(realpath);

use base qw(Exporter);
our @EXPORT = qw(get_config);
our @EXPORT_OK = qw(set_config);

my $config;

init();

sub init{
    my $feed_app_root;
    
    # get config file
    my $config_file;
    if (defined $ENV{HTFEED_CONFIG}){
        $config_file = $ENV{HTFEED_CONFIG};
    }
    else{
        my $this_module = 'HTFeed/Config.pm';
        my $path_to_this_module = dirname($INC{$this_module});
        $feed_app_root = realpath "$path_to_this_module/../..";
        $config_file = "$feed_app_root/etc/config.yaml";
    }

    # load config file
    eval{
        $config = YAML::XS::LoadFile($config_file);
        my $premis_config = YAML::XS::LoadFile(get_config('premis_config'));
        # copy premis config to main config
        while(my ($key, $val) = each(%$premis_config)) {
            $config->{$key} = $val;
        }
    };
    if ($@){ die ("loading $config_file failed: $@"); }

    # add feed_app_root to config
    unless (defined $config->{feed_app_root}){
        $config->{feed_app_root} = $feed_app_root;
    }
    
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
        croak( sprintf("%s is not in the config file", join('=>',@_)) ) if (!ref($cursor));
        $cursor = $cursor->{$hashlevel};
        
        # die if we try to traverse the tree where no path exists
        croak( sprintf("%s is not in the config file", join('=>',@_)) ) if (not defined $cursor);
    }
    return $cursor;
}

=set_config
change an entry after config is loaded
this probably shouldn't be used in production, but will be quite helpful in test scripts

set_config('setting','path'=>'to'=>'my'=>'setting')
=cut
sub set_config{
    my $setting = shift;
    my $leaf = pop;
    my $cursor = $config;
    foreach my $hashlevel (@_) {
        $cursor = $cursor->{$hashlevel};
        croak( sprintf("%s is not in the config file", join('=>',@_,$leaf)) ) if (! ref($cursor));
    }
    $cursor->{$leaf} = $setting;
    return 1;
}

1;

__END__
