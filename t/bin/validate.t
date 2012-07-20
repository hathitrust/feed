#!/usr/bin/perl
# tests package validation

use warnings;
use strict;

use YAML::Any ();
use File::Temp ();
use File::Copy;
use HTFeed::Config qw(set_config);
use Getopt::Long;
use FindBin;
use HTFeed::Volume;
use HTFeed::Log {root_logger => 'TRACE, file'};

use Test::More;

# get test config
my $config_file = "$FindBin::Bin/etc/package.yaml";
my $config_data = YAML::Any::LoadFile($config_file);

my $setup_mode;
GetOptions ( "s" => \$setup_mode );

my $damaged_staging = $config_data->{package_directory}->{damaged};
my $undamaged_staging = $config_data->{package_directory}->{undamaged};
my $validation_logs_dir = $config_data->{package_directory}->{logs};

# iterate through all volumes in config
my $package_types = $config_data->{package_types};
while( my ($package_type,$namespaces) = each %{ $package_types } ){
    while( my ($namespace,$objects) = each %{ $namespaces } ){
        foreach my $object ( @{ $objects } ){
            # get environment
            my ($objid,$fail_error_count) = @{$object};
            
            # make sure setup mode has been run if !$setup_mode
            die ("Missing error count or invalid input file, try $0 -s to run setup mode")
                if (!$setup_mode and !$fail_error_count);
            
            my $nspkg_path = "$package_type/$namespace";

            my $validation_dump = "$validation_logs_dir/$nspkg_path/$objid" . '.log';
            
            my @args = (
                    $package_type,
                    $namespace,
                    $objid,
                    "$damaged_staging/$nspkg_path",
                    "$undamaged_staging/$nspkg_path",
                    "$validation_logs_dir/$nspkg_path/$objid.log",
                    $fail_error_count,
            );
            
            # run tests
            test_success(@args);
            $fail_error_count = setup_failure(@args) if ($setup_mode);
            test_failure(@args) unless ($setup_mode);
            
            # save error count if we are in setup mode
            if ($setup_mode){
                $object = [$objid,$fail_error_count];
            }
        }
    }
}

if (! $setup_mode){
    # we tested for success, error count on fail, and list of errors on fail for each object,
    # so there are 3*n tests
    done_testing( $config_data->{volume_count} * 3 );
}
else{
    # in setup mode we test for failure rather than error count on fail and list of errors on fail
    # since we are generating that data, so there are only 2*n tests
    done_testing( $config_data->{volume_count} * 2 );
    
    # save yaml file, newly populated with error counts
    YAML::Any::DumpFile($config_file,$config_data);
}

# test_package($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path)
sub test_success{
    my ($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path) = @_;
    
    my ($volume, $vol_val);
    
    # get logfile
    my ($logfile_handle, $logfile_name) = get_temp();
        
    # validate undamaged package
    {
        set_config($undamaged_pkg_path,'staging'=>'ingest');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::VolumeValidator->new(volume => $volume);

        $vol_val->run();
    }
    
    # test that we succeeded
    ok($vol_val->succeeded(), "undamaged package validation for $package_type $namespace $objid");
}

# test_package($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path,$expected_log,$fail_error_count)
sub test_failure{
    my ($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path,$expected_log,$fail_error_count) = @_;
    
    my ($volume, $vol_val);
    
    # get logfile
    my ($logfile_handle, $logfile_name) = get_temp();
        
    # validate damaged package
	eval{
		set_config(0,'stop_on_error');
    	set_config($damaged_pkg_path,'staging'=>'ingest');

    	$volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
   		$vol_val = HTFeed::VolumeValidator->new(volume => $volume);
    	$vol_val->run();
	};

    # test number of errors
    is($vol_val->failed(),$fail_error_count,"error count for damaged package validation for $package_type $namespace $objid");
    
    my $diffs = `diff $expected_log $logfile_name`;
    if ($diffs eq q{}){
        pass("error log match for damaged package validation for $package_type $namespace $objid");
    }
    else{
        fail("error log match for damaged package validation for $package_type $namespace $objid");
        copy($logfile_name,"failure-$namespace-$objid-$$");
        open(my $diff_fh,">diffs-$namespace-$objid-$$");
        print $diff_fh $diffs;
        close($diff_fh);
    }
}

# test_package($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path,$expected_log)
sub setup_failure{
    my ($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path,$expected_log) = @_;
    
    my ($volume, $vol_val);
    
    # get logfile
    my ($logfile_handle, $logfile_name) = get_temp();
        
    # validate damaged package
    eval{
		set_config(0,'stop_on_error');
        set_config($damaged_pkg_path,'staging'=>'ingest');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::VolumeValidator->new(volume => $volume);

        $vol_val->run();
    };
   	 
    # test that we failed
    ok($vol_val->failed(),"damaged package validation for $package_type $namespace $objid");
    
    # put error log where it belongs
    copy($logfile_name,$expected_log);
    
    # return number of errors
    return $vol_val->failed();
}

# get_temp()
# creates logfile, sets L4P to log to the logfile, returns ($fh, $fname) for logfile
sub get_temp{
    # create logfile, File::Temp will unlink it automatically on DESTROY
    my $logfile_handle = File::Temp->new();
    my $logfile_name = $logfile_handle->filename;
    
    HTFeed::Log::set_logfile($logfile_name);
    
    return ($logfile_handle, $logfile_name);
}

