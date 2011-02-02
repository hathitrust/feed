#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use DBD::Mock;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use Test::DatabaseRow;
use Test::More;

#test for module (is this covered by general module testing?)
BEGIN {
    use_ok('HTFeed::DBTools');
}

require_ok('HTFeed::DBTools');

#connect to DB
my $dbh = HTFeed::DBTools::get_dbh();

#Sample row test A
local $Test::DatabaseRow::dbh = $dbh;

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

done_testing();

__END__
