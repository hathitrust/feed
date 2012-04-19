use warnings;
use strict;
use v5.10;
use Carp;

use lib "lib";
use HTFeed::Version qw(:no_getopt get_vstring get_full_version_string get_production_ok);

my $directive = shift;

given( $directive ) {
    when ('brand_version')     { brand_version(@ARGV); }
    when ('write_path_config') { write_path_config(@ARGV); }
    when ('install_dir')       { install_dir(@ARGV); }
}

# brand Version.pm in blib with found version information (usualy from git)
sub brand_version {
    my $version_pm = "blib/lib/HTFeed/Version.pm";
    croak ("could not find Version.pm at $version_pm")
        unless(-f $version_pm);

    my $version_block = _generate_version_block();

    ##my $cmd = q!perl -pe 'if ($_ =~ /HTFEED_VERSION_STRINGS$/){$_ = q+%s+.qq+\n+}' -i %s!;
    ##$cmd = sprintf($cmd,$version_block,$version_pm);
    ##
    ##my $result = system($cmd);
    ##croak ("branding Version.pm failed")
    ##    if($result);
    _replace($version_pm,'HTFEED_VERSION_STRINGS',$version_block,'branding Version.pm');

    return;
}

sub write_path_config {
    # find paths
    ## TODO: Eliminate hard coding here
    my $feed_etc = '/usr/local/etc/feed';
    my $feed_bin = '/usr/local/bin';
    my $feed_var = '/usr/local/var/feed';

    my $config_pm = 'blib/lib/HTFeed/Config.pm';

    _replace($config_pm,'FEED_ETC',"my \$feed_etc = $feed_etc; # FEED_ETC") if($feed_etc);
    _replace($config_pm,'FEED_BIN',"my \$feed_bin = $feed_bin; # FEED_BIN") if($feed_bin);
    _replace($config_pm,'FEED_VAR',"my \$feed_var = $feed_var; # FEED_VAR") if($feed_var);
    
    return;
}

sub install_dir {
    my $src = shift;
    my $target = shift;

    my $result = system("cp -r $src $target");
    croak ("installing $src to $target failed")
        if($result);
    
    return;
}

sub _generate_version_block {
	my $syntax = 'my ($vstring,$full_version_string,$production_ok) = ("%s","%s","%s"); # HTFEED_VERSION_STRINGS';

	my $full_version_string = get_full_version_string();
	croak "I will not make from a dirty git repo. Commit or stash." if ($full_version_string =~ /dirty/);

	$syntax = sprintf($syntax,get_vstring(),$full_version_string,get_production_ok());

	# test syntax
	eval $syntax;
	croak ("error generating version information: $@")
        if($@ or $syntax !~ /HTFEED_VERSION_STRINGS$/);

    return $syntax;
}

# _replace($file, $tag, $newline, $action_name)
sub _replace {
    my ($file, $tag, $newline, $action_name) = @_;
    my $cmd = q!perl -pe 'if ($_ =~ /%s$/){$_ = q+%s+.qq+\n+}' -i %s!;
    $cmd = sprintf($cmd,$tag,$newline,$file);
    my $result = system($cmd);
    croak ("$action_name failed")
        if($result);
    
    return;
}
