use warnings;
use strict;
use v5.10;

use ExtUtils::MakeMaker;

use FindBin;
use lib "$FindBin::Bin/lib";

# use --make-dist flag to build makefile for making a distributable package rather than actually installing
my ($make_dist) = grep(/^--make-dist$/,@ARGV);

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
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
		'Test::DatabaseRow'		=> 0,
		'Test::Harness'			=> 0,
		'Test::More'			=> 0,
		'Test::Most'			=> 0,
		'Test::Class'			=> 0,
	},
	CONFIGURE_REQUIRES => { "ExtUtils::MakeMaker" => 0 },
	INSTALLDIRS => 'site',
	INSTALL_BASE => '/usr/local', # TODO: this does what we want, but is the wrong assertion to make it happen
	EXE_FILES => [ split(/\s+/,qx!cat MANIFEST | grep ^bin.*pl\$!) ], # TODO: no more .pl extensions for these
	MAN3PODS => { }, # disable MAN3 for now
);

sub MY::post_constants {
	return <<'MAKE_CONSTANTS'

MAKE_CONSTANTS
}

# install etc directory
sub MY::postamble {
	## TODO: remove hard coded paths, use $(PERL), et al

	return <<'DIST_MAKE_FRAG' if($make_dist);
# disable install target
install ::
	false

dist : brand_version manifest inject_copyright

distdir : brand_version manifest inject_copyright

# remove generated MANIFEST.SKIP, MANIFEST
clean_manifest :
	$(RM_RF) MANIFEST
	mv MANIFEST.SKIP.bak MANIFEST.SKIP

# write version info to Version.pm
brand_version ::
	perl InstallerTools.PL brand_version

inject_copyright :
	perl InstallerTools.PL inject_copyright $(TO_INST_PM)

realclean purge :: clean_manifest
	$(NOECHO) $(NOOP)

DIST_MAKE_FRAG

	return <<'INSTALL_MAKE_FRAG'
pure_all :: etc_to_blib
	$(NOECHO) $(NOOP)

install :: write_path_config install_etc
	$(NOECHO) $(NOOP)

etc_to_blib ::
	perl InstallerTools.PL install_dir etc blib/etc

install_etc ::
	perl InstallerTools.PL install_dir blib/etc /usr/local/etc/feed

# write file paths to Config.pm
write_path_config ::
	perl InstallerTools.PL write_path_config

INSTALL_MAKE_FRAG

}

1;

__END__
