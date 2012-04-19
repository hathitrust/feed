use ExtUtils::MakeMaker;

use FindBin;
use lib "$FindBin::Bin/lib";

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
		'Archive::Extract'		=> 0,
		'Carp'					=> 0,
		'Cwd'					=> 0,
		'DBD::mysql'			=> 0, # possibly not needed for local install
		'DBD::SQLite'			=> 0, # possibly not needed for distribution
		'DBI'					=> 0,
		'Data::Dumper'			=> 0,
		'Data::UUID'			=> 0,
		'Date::Manip'			=> 0,
		'Date::Parse'			=> 0,
		'Digest::MD5'			=> 0,
		'Encode'				=> 0,
		'Exporter'				=> 0,
		'File::Basename'		=> 0,
		'File::Copy'			=> 0,
		'File::Fetch'			=> 0,
		'File::Find'			=> 0,
		'File::Pairtree'		=> 0,
		'File::Path'			=> 0,
		'File::Spec'			=> 0,
		'File::Temp'			=> 0,
		'Filesys::Df'			=> 0,
		'FindBin'				=> 0,
		'Getopt::Long'			=> 0,
		'IO::File'				=> 0,
		'IO::Handle'			=> 0,
		'IO::Pipe'				=> 0,
		'IO::Uncompress::Unzip'	=> 0,
		'IPC::Open3'			=> 0,
		'Image::ExifTool'		=> 0,
		'LWP::UserAgent'		=> 0,
		'List::MoreUtils'		=> 0,
		'List::Util'			=> 0,
		'Log::Log4perl'			=> 0,
		'Log::Log4perl::Level'	=> 0,
		'Mail::Mailer'			=> 0,
		'POSIX'					=> 0,
		'Pod::Usage'			=> 0,
		'Readonly'				=> 0,
		'Scalar::Util'			=> 0,
		'Switch'				=> 0,
		'Sys::Hostname'			=> 0,
		'Time::Local'			=> 0,
		'Time::localtime'		=> 0,
		'XML::LibXML'			=> 0,
		'XML::LibXML::SAX'		=> 0,
		'YAML::Any'				=> 0,
		'YAML::AppConfig'		=> 0,
		## site specific, possibly rework this ##
		'HTTP::DAV'				=> 0,
		'JSON::XS'				=> 0,
		'Spreadsheet::WriteExcel'	=> 0,
		'SOAP::Lite'			=> 0,
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

	return <<'MAKE_FRAG';
pure_all :: etc_to_blib brand_version write_path_config
	$(NOECHO) $(NOOP)

install :: install_etc
	$(NOECHO) $(NOOP)

etc_to_blib ::
	perl InstallerTools.PL etc blib/etc

install_etc ::
	perl InstallerTools.PL blib/etc /usr/local/etc/feed

# write version info to Version.pm
brand_version ::
	perl InstallerTools.PL brand_version

# write file paths to Config.pm
write_path_config ::
	perl InstallerTools.PL write_path_config

# remove generated MANIFEST.SKIP
clean_manifest :
	mv MANIFEST.SKIP.bak MANIFEST.SKIP

# remove generated MANIFEST.SKIP
clean_manifest :
	mv MANIFEST.SKIP.bak MANIFEST.SKIP

# make distributable packages
external_dist : manifest clean_manifest dist

internal_dist : _hide_internal_code_MANIFEST manifest clean_manifest _replace_internal_code_MANIFEST dist

_hide_internal_code_MANIFEST :
	mv internal_code_MANIFEST.SKIP internal_code_MANIFEST.SKIP.bak

_replace_internal_code_MANIFEST :
	mv internal_code_MANIFEST.SKIP.bak internal_code_MANIFEST.SKIP

MAKE_FRAG
}

1;

__END__
	