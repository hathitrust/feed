#!/usr/bin/perl
# yale unit test: ImageRemediate

=info

This test is part of the testing suite for Yale ingest
Current Stage: HTFeed::PackageType::Yale::ImageRemediate
Four tests: all_pass, val_pass, rem_pass & all_fail

=cut

use warnings;
use strict;
use YAML::XS ();
use File::Temp ();
use File::Copy;
use HTFeed::Config qw(set_config);
use FindBin;
use HTFeed::Volume;
use HTFeed::PackageType::Yale::ImageRemediate;
use HTFeed::Log {root_logger => 'TRACE, file'};
use Test::More;

# get test config
my $config_file = "$FindBin::Bin/../etc/package.yaml";
my $config_data = YAML::XS::LoadFile($config_file);

my $all_pass_staging = $config_data->{package_directory}->{all_pass};
my $val_pass_staging = $config_data->{package_directory}->{val_pass};
my $rem_pass_staging = $config_data->{package_directory}->{rem_pass};

# TODO: staging setup
# ImageRemediate assumes certain preingest steps have occured.
#
#

# iterate through all volumes in config
my $package_types = $config_data->{package_types};

while( my ($package_type,$namespaces) = each %{ $package_types } ){
    while( my ($namespace,$objects) = each %{ $namespaces } ){
        foreach my $object ( @{ $objects } ){

		next unless $package_type eq "yale";

            # get environment
            my ($objid,$fail_error_count) = @{$object};
			my $source;

            my @args = (
					$package_type,
					$namespace,
                    $objid,
					$source,
                    $fail_error_count,
            );

            # run tests
            test_all_pass(@args);
			test_val_pass(@args);
			test_rem_pass(@args);
        }
    }
}

#we tested for success in three cases
done_testing( $config_data->{volume_count} *3);

# "good" package should pass all stages
sub test_all_pass{
    my ($namespace, $package_type, $objid,$source) = @_;
    my ($volume, $vol_val);
    $source = $all_pass_staging;    

    {
        set_config($source,'staging'=>'ingest');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::PackageType::Yale::ImageRemediate->new(volume => $volume);
		$vol_val->run();
    }

    # test that we succeeded
    ok($vol_val->succeeded(), "all_pass package validation for $package_type $objid");
}

# package should pass remediation AND validation
sub test_val_pass {
	my ($namespace, $package_type, $objid, $source) = @_;
	my ($volume, $vol_val);
	$source = $val_pass_staging;

    {
        set_config($source,'staging'=>'ingest');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::PackageType::Yale::ImageRemediate->new(volume => $volume);
        $vol_val->run();
    }

    # test that we succeeded
    ok($vol_val->succeeded(), "val_pass package validation for $package_type $objid");
}


# package should pass remediation (but will fail validation)
sub test_rem_pass {
	my ($namespace, $package_type, $objid, $source) = @_;
	my ($volume, $vol_val);
	$source = $rem_pass_staging;

    {
        set_config($source,'staging'=>'ingest');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::PackageType::Yale::ImageRemediate->new(volume => $volume);
        $vol_val->run();
    }

    # test that we succeeded
    ok($vol_val->succeeded(), "val_pass package validation for $package_type $objid");
}
