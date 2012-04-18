use ExtUtils::MakeMaker;

use FindBin;
use lib "$FindBin::Bin/lib";
use HTFeed::Version qw(:no_getopt);

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME          => 'HTFeed',
    VERSION_FROM  => 'lib/HTFeed.pm', # finds \$VERSION
    AUTHOR        => 'Library IT - Core Services (lit-cs-ingest@umich.edu)',
    ABSTRACT      => 'HathiTrust repository toolkit',
    PREREQ_PM     => {
        'Algorithm::LUHN'         => 0,
        'Any::Moose'              => 0,
        'Archive::Extract'        => 0,
        'Carp'                    => 0,
        'Cwd'                     => 0,
        'DBD::mysql'              => 0, # possibly not needed for local install
        'DBD::SQLite'             => 0, # possibly not needed for distribution
        'DBI'                     => 0,
        'Data::Dumper'            => 0,
        'Data::UUID'              => 0,
        'Date::Manip'             => 0,
        'Date::Parse'             => 0,
        'Digest::MD5'             => 0,
        'Encode'                  => 0,
        'Exporter'                => 0,
        'File::Basename'          => 0,
        'File::Copy'              => 0,
        'File::Fetch'             => 0,
        'File::Find'              => 0,
        'File::Pairtree'          => 0,
        'File::Path'              => 0,
        'File::Spec'              => 0,
        'File::Temp'              => 0,
        'Filesys::Df'             => 0,
        'FindBin'                 => 0,
        'Getopt::Long'            => 0,
        'IO::File'                => 0,
        'IO::Handle'              => 0,
        'IO::Pipe'                => 0,
        'IO::Uncompress::Unzip'   => 0,
        'IPC::Open3'              => 0,
        'Image::ExifTool'         => 0,
        'LWP::UserAgent'          => 0,
        'List::MoreUtils'         => 0,
        'List::Util'              => 0,
        'Log::Log4perl'           => 0,
        'Log::Log4perl::Level'    => 0,
        'Mail::Mailer'            => 0,
        'POSIX'                   => 0,
        'Pod::Usage'              => 0,
        'Readonly'                => 0,
        'Scalar::Util'            => 0,
        'Switch'                  => 0,
        'Sys::Hostname'           => 0,
        'Time::Local'             => 0,
        'Time::localtime'         => 0,
        'XML::LibXML'             => 0,
        'XML::LibXML::SAX'        => 0,
        'YAML::Any'               => 0,
        'YAML::AppConfig'         => 0,
        ## site specific, possibly rework this ##
        'HTTP::DAV'               => 0,
        'JSON::XS'                => 0,
        'Spreadsheet::WriteExcel' => 0,
        'SOAP::Lite'              => 0,
    },
    BUILD_REQUIRES => {
        'Test::DatabaseRow'       => 0,
        'Test::Harness'           => 0,
        'Test::More'              => 0,
        'Test::Most'              => 0,
        'Test::Class'             => 0,
    },
    CONFIGURE_REQUIRES => { "ExtUtils::MakeMaker" => 0 },
    INSTALLDIRS => 'site',
    INSTALL_BASE => '/usr/local/feed',
    EXE_FILES => [ split(/\s+/,qx!cat MANIFEST | grep ^bin.*pl\$!) ],
);
