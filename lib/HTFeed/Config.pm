package HTFeed::Config;

use warnings;
use strict;
use YAML::AppConfig;
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
    # get app root and config dir
    my $feed_app_root;
    my $config_dir;
    {
        my $this_module = __PACKAGE__ . '.pm';
		$this_module =~ s/::/\//g;
        my $path_to_this_module = dirname($INC{$this_module});
        $feed_app_root = realpath "$path_to_this_module/../..";
        $config_dir = "$feed_app_root/etc/config";
    }
    
    # load config files
    my $config_file;
    eval{
        foreach $config_file (sort(glob("$config_dir/*.yml"))){
            if($config){
                $config->merge(file => $config_file);
            } else {
                $config = YAML::AppConfig->new(file => $config_file);
            }
        }
    };
    if ($@){ die ("loading $config_file failed: $@"); }

    # add feed_app_root to config
    unless (defined $config->{feed_app_root}){
        $config->set('feed_home',$feed_app_root);
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
    my $cursor = $config->get(shift @_);
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

    if(!@_) {
        $config->set($leaf,$setting);
    } else {
        my $topkey = shift @_;
        my $topval = $config->get($topkey);
        my $cursor = $topval;
        foreach my $hashlevel (@_) {
            $cursor = $cursor->{$hashlevel};
            croak( sprintf("%s is not in the config file", join('=>',@_,$leaf)) ) if (! ref($cursor));
        }
        $cursor->{$leaf} = $setting;
        $config->set($topkey,$topval);
    }

    return 1;
}

1;

__END__
