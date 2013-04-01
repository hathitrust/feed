use warnings;
use strict;
#use v5.10;

use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

use FindBin;
use lib "$FindBin::Bin/lib";

# use --make-dist flag to build makefile for making a distributable package rather than actually installing
my ($make_dist) = grep(/^--make-dist$/,@ARGV);

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my $mm = WriteMakefile(
	NAME			=> 'HTFeed',
	VERSION_FROM	=> 'lib/HTFeed.pm', # finds \$VERSION
	AUTHOR			=> 'Library IT - Core Services (lit-cs-ingest@umich.edu)',
	ABSTRACT		=> 'HathiTrust repository toolkit',
	PREREQ_PM		=> {
		'Algorithm::LUHN'		=> 0,
		'Any::Moose'			=> 0,
		'Data::UUID'			=> 0,
		'Date::Manip'			=> 0,
		'Date::Parse'			=> 0,
		'File::Pairtree'		=> 0,
		'Filesys::Df'			=> 0,
		'Image::ExifTool'		=> 0,
		'LWP'					=> 0,
		'List::MoreUtils'		=> 0,
		'Log::Log4perl'			=> 0,
		'Readonly'				=> 0,
		'XML::LibXML'			=> 0,
		'YAML::Any'				=> 0,
	},
	BUILD_REQUIRES => {
		'Test::Harness'			=> 0,
		'Test::More'			=> 0,
		'Test::Most'			=> 0,
		'Test::Class'			=> 0,
	},
	CONFIGURE_REQUIRES => { "ExtUtils::MakeMaker" => 0 },
	EXE_FILES => [ split(/\s+/,qx!cat MANIFEST | grep ^bin.*pl\$!) ], # TODO: no more .pl extensions for these
	MAN3PODS => { }, # disable MAN3 for now
);

# find paths
1;
my $feed_etc = "$mm->{PREFIX}/etc/feed";
my $feed_bin = $mm->{INSTALLSITESCRIPT};
my $feed_var = "$mm->{PREFIX}/var/feed";

# substitute makefile parameters
foreach my $v (\$feed_etc,\$feed_bin,\$feed_var) {
    while($$v =~ /\$\(/) {
        $$v =~ s/\$\((\w+)\)/$mm->{$1}/g;
    }
}

# TODO: us etemp dir of some kind; blib doesn't work
my $config_pm = 'lib/HTFeed/Config.pm';

_replace($config_pm,'FEED_ETC',"my \$feed_etc = \"$feed_etc\"; # FEED_ETC") if($feed_etc);
_replace($config_pm,'FEED_BIN',"my \$feed_bin = \"$feed_bin\"; # FEED_BIN") if($feed_bin);
_replace($config_pm,'FEED_VAR',"my \$feed_var = \"$feed_var\"; # FEED_VAR") if($feed_var);


sub MY::post_constants {
	my @manifest_files = keys %{maniread()};
	my @etc_files = grep {/^etc\//} @manifest_files;
	return unless (scalar @etc_files);
	my $to_inst_etc = 'TO_INST_ETC = ' . join(" \\\n\t",@etc_files) . "\n";
	return $to_inst_etc;
}

# install etc directory
sub MY::postamble {
	## TODO: remove hard coded paths, use $(PERL), et al

	return <<'DIST_MAKE_FRAG' if($make_dist);
# disable install target
install ::
	false
    my @etc_files = grep {/^etc\//} @manifest_files;

dist : brand_version inject_copyright 

distdir : brand_version inject_copyright 

fix_manifest_skip :
	([ -f MANIFEST.SKIP.bak ] && mv MANIFEST.SKIP.bak MANIFEST.SKIP) || [ ! -f MANIFEST.SKIP.bak ]

# remove generated MANIFEST.SKIP, MANIFEST
clean_manifest : fix_manifest_skip
	$(RM_RF) MANIFEST

# write version info to Version.pm
brand_version ::
	perl InstallerTools.PL brand_version

inject_copyright :
	perl InstallerTools.PL inject_copyright $(TO_INST_PM)

realclean purge :: clean_manifest
	$(NOECHO) $(NOOP)

DIST_MAKE_FRAG

	return <<'INSTALL_MAKE_FRAG'
pure_all :: validate_cache etc_to_blib db_to_blib
	$(NOECHO) $(NOOP)

validate_cache ::
	g++ -o blib/bin/validateCache src/validateCache.cpp -lxerces-c

install :: install_etc install_db
	$(NOECHO) $(NOOP)

etc_to_blib ::
	$(ABSPERLRUN) -MExtUtils::Install -e 'install {"etc" => "blib/etc"}'

db_to_blib ::
	$(ABSPERLRUN) -MExtUtils::Install -e "pm_to_blib( {'etc/feed.template.sqlite3' => 'blib/var/db/feed.db'}, '$(INST_LIB)/auto' )"

install_etc ::
	$(ABSPERLRUN) -MExtUtils::Install -e "install {'blib/etc' => '$(PREFIX)/etc/feed'}"
	chmod -R u+w $(PREFIX)/etc

install_db ::
	$(ABSPERLRUN) -MExtUtils::Install -e "install {'blib/var' => '$(PREFIX)/var/feed'}"
	chmod -R u+w $(PREFIX)/var/feed

INSTALL_MAKE_FRAG

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
    die "ERROR: $file not found" unless (-f $file);
    my $cmd = q!perl -pe 'if ($_ =~ /%s$/){$_ = q+%s+.qq+\n+}' -i '%s'!;
    $cmd = sprintf($cmd,$tag,$newline,$file);
    my $result = system($cmd);
    die ("$action_name failed")
        if($result);

    return;
}


1;

__END__
