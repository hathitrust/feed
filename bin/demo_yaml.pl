#!/usr/bin/perl

# Dump perl data structures to YAML
# add to $data as needed

# See also: Config.pm, config.yaml

use warnings;
use strict;

use Data::Dumper;
use YAML::XS;

my $data = {
    database =>
        {
            username => "uname",
            password => "password",
            datasource => "dbi:mysql:my_db:mysql-sdr",
        },
    config_directory => "/some/path/etc",
    l4p_config => "config.l4p",
    staging_directory => "/path/to/staging",
    download_directory => "/path/to/download",
    jhove => "/l/local/bin/jhove",
    jhoveconf => "/l/local/jhove/conf/jhove.conf",
};

print Dump $data;