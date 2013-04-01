use warnings;
use strict;
use v5.10;
use Carp;
use File::Basename;
use Cwd qw(realpath);

use lib "lib";
use HTFeed::Version qw(:no_getopt get_vstring get_full_version_string get_production_ok);

my $directive = shift;

given( $directive ) {
    when ('brand_version')     { brand_version(@ARGV); }
    when ('inject_copyright')  { write_copyright(@ARGV); }
}

# brand Version.pm in blib with found version information (usualy from git)
sub brand_version {
    my $version_pm = "lib/HTFeed/Version.pm";
    croak ("could not find Version.pm at $version_pm")
        unless(-f $version_pm);

    my $version_block = _generate_version_block();

    _replace($version_pm,'HTFEED_VERSION_STRINGS',$version_block,'branding Version.pm');

    return;
}

sub write_copyright {
    my $copyright_source_file = 'lib/HTFeed.pm';
    my $copyright_text = `perl -MPod::Select -e 'podselect({-sections => ["AUTHOR|COPYRIGHT"]}, "lib/HTFeed.pm")'`;
    my @files = @_;

    foreach my $file (@files) {
        _replace($file,'INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE',$copyright_text);
    }
}

sub _generate_version_block {
	my $syntax = 'my ($vstring,$full_version_string,$production_ok) = ("%s","%s","%s"); # HTFEED_VERSION_STRINGS';

	my $full_version_string = get_full_version_string();
#	croak "I will not make from a dirty git repo. Commit or stash." if ($full_version_string =~ /dirty/);

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
    # get real paths here, no symlinks
    if (-l $file) {
        print "resolving link: $file points to ";
        my $path = dirname($file);
        my $link = readlink($file);
        $file = $link =~ /^\// ? $link : realpath("$path/$link");
        print "$file\n";
    }
    croak "ERROR: $file not found" unless (-f $file);
    my $cmd = q!perl -pe 'if ($_ =~ /%s$/){$_ = q+%s+.qq+\n+}' -i '%s'!;
    $cmd = sprintf($cmd,$tag,$newline,$file);
    my $result = system($cmd);
    croak ("$action_name failed")
        if($result);

    return;
}

