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
our @EXPORT_OK = qw(set_config get_tool_version);

my $config;

init();

## TODO: make get_config die on failed top level requests

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
    my $filename;
    eval{
        my @config_files = sort(glob("$config_dir/*.yml"));
        push (@config_files, $ENV{HTFEED_CONFIG}) if(defined $ENV{HTFEED_CONFIG});
        foreach my $config_file (@config_files) {
			$filename = $config_file;
            if($config){
                $config->merge(file => $config_file);
            } else {
                $config = YAML::AppConfig->new(file => $config_file);
            }
        }
    };
    if ($@){ die ("loading $filename failed: $@"); }

    # add feed_app_root to config
    unless (defined $config->{feed_app_root}){
        $config->set('feed_home',$feed_app_root);
    }
    
    ## TODO: check file validity, can't do this until we establish what the file will look like
    ## TODO: test script to dig out all the config vars and check against config file
}

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

# this probably shouldn't be used in production, but will be quite helpful in test scripts
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

sub get_tool_version {

    my $package_id = shift;
    my $to_eval    = get_config( 'premis_tools', $package_id );
    if ( !$to_eval ) {
        croak("Configuration error: $package_id missing from premis_tools");
        return $package_id;
    }

    my $version = eval($to_eval);
    if ( $@ or !$version ) {
        croak("Error getting version for $package_id: $@");
        return $package_id;
    }
    else {
        return $version;
    }
}

sub perl_mod_version {
    my $module  = shift;
    my $mod_req = $module;
    $mod_req =~ s/::/\//g;
    my $toreturn;
    eval { require "$mod_req.pm"; };
    if ($@) {
        croak( "Error loading $module: $@" );
    }
    no strict 'refs';
    my $version = ${"${module}::VERSION"};
    if ( defined $version ) {
        return "$module $version";
    }
    else {
        croak("Can't find ${module}::VERSION" );
    }
}

sub local_directory_version {
    my $package   = shift;
    my $tool_root = get_config("premis_tool_local");
    if ( not -l "$tool_root/$package" ) {
        croak("$tool_root/$package not a symlink" );
    }
    else {
        my $package_target;
        if ( !( $package_target = readlink("$tool_root/$package") ) ) {
            croak("Error in readlink for $tool_root/$package: $!" ) if $!;
            return $package;
        }

        my ($package_version) = ( $package_target =~ /$package-([\w.]+)$/ );
        if ($package_version) {
            return "$package $package_version";
        }
        else {
            croak( "Couldn't extract version from symlink $package_version for $package");
            return $package;
        }

    }
}

sub system_version {
    my $package = shift;
    my $version = `rpm -q $package`;

    if ( $? or $version !~ /^$package[-.\w]+/ ) {
        croak("RPM returned '$version' with status $? for package $package" );
    }
    else {
        chomp $version;
        return $version;
    }
}



1;

__END__

=head1 NAME

HTFeed::Config - Manage HTFeed configuration settings

=head1 SYNOPSIS

Get and Set methods for interaction with config.yml files

=head1 DESCRIPTION

Config.pm provides the mechanism for referencing all configuration values throughout HTFeed.
Helpful methods for getting config values can be found in main class modules such as METS, Volume, and VolumeValidator.

=head2 METHODS

=over 4

=item get_config()

Retrieves a value from a config file

Use get_config to reference a configuration value:

    use HTFeed::Config qw(get_config);
    get_config('staging' => 'ingest');
    get_config('jhove');


=item set_config()

Use set_config to (re)set a config entry after the config file has been loaded.

B<NOTE:> This method should be used for testing purposes only.

    use HTFeed::Config qw(set_config);
    set_config('setting','path'=>'to'=>'my'=>'setting');

=item init()

Loads the appropriate configuration files

=back

=item get_tool_version()

Get the version of a tool defined in the premis_tools section in the configuration file.

$tool_version = get_tool_version($package_identifier);

INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
