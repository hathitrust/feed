#!/usr/bin/perl

# use this to make sure config_yaml_prototype_struct.pl is doing what you think it is
# ./dump_yaml.pl in-yaml

use warnings;
use strict;

use Data::Dumper;
use YAML::XS;

my $config = YAML::XS::LoadFile(shift);

print Dumper $config;