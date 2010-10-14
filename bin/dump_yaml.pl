#!/usr/bin/perl

# use this to make sure your yaml is doing what you think it is
# usage: ./dump_yaml.pl in-yaml

use warnings;
use strict;

use Data::Dumper;
use YAML::XS;

my $data = YAML::XS::LoadFile(shift);

print Dumper $data;
