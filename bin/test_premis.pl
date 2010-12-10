#!/usr/bin/perl

use HTFeed::Volume;
use HTFeed::METS;
use DBI;
use HTFeed::Log {root_logger => 'INFO, screen'};

my $volume = new HTFeed::Volume(objid => '39002001151019',
    namespace => 'yale',
    packagetype => 'yale');

my $mets = new HTFeed::METS(volume => $volume);

$mets->_add_premis();
