#!/usr/bin/perl

# use this to develop the prototypical YAML file:
# 1) add to $config as needed
# 2) ./config_yaml_prototype_struct.pl > ../etc/config.yaml

# See also: Config.pm

use warnings;
use strict;

use Data::Dumper;
use YAML::XS;

my $config = {
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

print "# this is a generated file\n";
print "# see: bin/config_yaml_prototype_struct.pl\n";
print Dump $config;