#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use FindBin;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use Test::DatabaseRow;
use HTFeed::Log {root_logger => 'INFO, screen'};
use Test::More;

# get test config
my $config_file = "$FindBin::Bin/etc/objid.yaml";
my $config_data = YAML::XS::LoadFile($config_file);

#test for module
BEGIN {
    use_ok('HTFeed::DBTools');
}

require_ok('HTFeed::DBTools');

#connect to DB
my $dbh = HTFeed::DBTools::get_dbh();

local $Test::DatabaseRow::dbh = $dbh;


#XXX Sample Tests XXX#

	#Sample row test A
	row_ok(
		sql		=> "select * from blacklist where id = '39015000531544'",
		tests	=> [namespace => "mdp"],
		label	=> "volume 39015000531544 has namespace mdp"
	);
	
	#Sample row test B
	row_ok(
		table	=> "blacklist",
		where	=> [id => 39015000531544],
		tests	=> [namespace => "mdp"],
		label	=> "volume 39015000531544 has namespace mdp"
	);

#XXX End Sample XXX#

done_testing();

__END__
