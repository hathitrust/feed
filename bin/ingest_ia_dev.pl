#!/usr/bin/perl

# For testing with internet archive items in development. Do not use in
# production.

# If only the IA ID is known, you can get the arkid with the Internet Archive
# command-line client:
# https://archive.org/services/docs/api/internetarchive/cli.html
# arkid=$(ia # metadata $ia_id | jq -r '.metadata."identifier-ark"')

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Log { root_logger => 'INFO, screen' };
use HTFeed::Version;

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::RunLite qw(runlite);
use File::Pairtree qw(id2ppath s2ppchars);
use Date::Manip;

Date_Init();

my $obj_dir = get_config('repository','obj_dir');
my $backdate = UnixDate(ParseDate("1 week ago"),"%Y-%m-%d");

my ($ia_id, $namespace, $arkid) = @ARGV;

die("Usage: $0 ia_id namespace arkid\n") unless $ia_id and $namespace and $arkid;

get_dbh()->do("REPLACE INTO feed_ia_arkid (ia_id, namespace, arkid) VALUES ('$ia_id','$namespace','$arkid')");
# get_dbh()->do("REPLACE INTO feed_zephir_items (namespace, id, collection, digitization_source) VALUES ('$namespace','$arkid','TEST','ia')");

my $volume = HTFeed::Volume->new(packagetype => 'ia', namespace => $namespace, objid => $arkid);

runlite(volumegroup => new HTFeed::VolumeGroup(volumes => [$volume]), logger => 'ingest_ia_dev.pl', verbose => 1);

my $pt_path="$obj_dir/$namespace/" . id2ppath("$arkid") . s2ppchars("$arkid");

system("find $pt_path | xargs touch -d '$backdate'")
