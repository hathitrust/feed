#!/usr/bin/perl
# tests objid validation

use warnings;
use strict;

use YAML::Any ();
use FindBin;
use HTFeed::Volume;
use HTFeed::Log {root_logger => 'INFO, file'};

use Test::Most;

# get test config
my $config_file = "$FindBin::Bin/etc/objid.yaml";
my $config_data = YAML::Any::LoadFile($config_file);

my $damaged_count = $config_data->{damaged}->{count};
my $undamaged_count = $config_data->{undamaged}->{count};
my $damaged_package_types = $config_data->{damaged}->{package_types};
my $undamaged_package_types = $config_data->{undamaged}->{package_types};

# test damaged
while( my ($package_type,$namespaces) = each %{ $damaged_package_types } ){
    while( my ($namespace,$objids) = each %{ $namespaces } ){
        foreach my $objid ( @{ $objids } ){
            dies_ok { HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type) } "$package_type $namespace $objid is a bad objid";
        
    	}
	}
}

# test undamaged
while( my ($package_type,$namespaces) = each %{ $undamaged_package_types } ){
    while( my ($namespace,$objids) = each %{ $namespaces } ){
        foreach my $objid ( @{ $objids } ){
            lives_ok { HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type) } "$package_type $namespace $objid is a valid objid";
        }
    }
}

# one test per objid
done_testing( $damaged_count + $undamaged_count );
