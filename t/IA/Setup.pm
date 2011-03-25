#!/usr/bin/perl
package Setup;

#XXX special elements for IA; but could adjust to make base case for all tests

use warnings;
use strict;
use YAML::XS ();
use File::Temp ();
use File::Copy;
use HTFeed::Config qw(set_config);
use Getopt::Long;
use FindBin;
use HTFeed::Volume;
use HTFeed::Log {root_logger => 'TRACE, file'};

sub new{
	my $class = shift;
	my $self = shift;

	# get test config
    my $config_file = "$FindBin::Bin/../etc/package.yaml";
    my $config_data = YAML::XS::LoadFile($config_file);

	my ($path, $objid, $package_type, $namespace);
	my $fail_error_count;
	my $namespaces;
	my $objects;

    $path = $config_data->{package_directory}->{undamaged};

    # iterate through all volumes in config
    my $package_types = $config_data->{package_types};
    while( ($package_type,$namespaces) = each %{ $package_types } ){
        while( ($namespace,$objects) = each %{ $namespaces } ){
            foreach my $object ( @{ $objects } ){
                # get environment
                ($objid,$fail_error_count) = @{$object};

                #XXX alter for general case
                next unless $package_type eq "ia";

				$self = {
					path => $path,
					objid => $objid,
					package_type => $package_type,
					namespace => $namespace,
				};
			}
		}
    }
	bless $self, $class;
	return $self;
}

sub getPath{
my($self) = @_;
return $self->{path};
}

sub getObjid{
my($self) = @_;
return $self->{objid};
}

sub getPkg{
my($self) = @_;
return $self->{package_type};
}

sub getNamespace{
my($self) = @_;
return $self->{namespace};
}

1;
