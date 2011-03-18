#!/usr/bin/perl
# yale unit test: Validate

=info

This test is part of the testing suite for Yale ingest
Current Stage: HTFeed::VolumeValidator
Four tests: all_pass, val_pass, rem_pass & all_fail

=cut

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
use Test::More;

# get test config
my $config_file = "$FindBin::Bin/etc/yale.yaml";
my $config_data = YAML::XS::LoadFile($config_file);

my $setup_mode;
GetOptions ( "s" => \$setup_mode );

my $all_pass_staging = $config_data->{package_directory}->{all_pass};
my $val_pass_staging = $config_data->{package_directory}->{val_pass};
my $rem_pass_staging = $config_data->{package_directory}->{rem_pass};
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

			my $validation_dump="$validation_logs_dir/$objid" . '.log';

			# get log naming convention
			my $log = "$validation_logs_dir/$objid.log";

			my $source;

            my @args = (
					$package_type,
					$namespace,
                    $objid,
					$source,
                    $log,
                    $fail_error_count,
            );

            # run tests
            test_all_pass(@args);
			test_val_pass(@args);
            $fail_error_count = setup_failure(@args) if ($setup_mode);
            test_rem_pass(@args) unless ($setup_mode);
            
            # save error count if we are in setup mode
            if ($setup_mode){
                $object = [$objid,$fail_error_count];
            }

        }
    }
}


if (! $setup_mode){
    # we tested for success (all_pass & val_pass), error count on fail, and list of errors on fail for each object,
    # so there are 4*n tests
    done_testing( $config_data->{volume_count} *4 );
}
else{
    # in setup mode we test for failure rather than error count on fail and list of errors on fail
    # since we are generating that data, so there are only 3*n tests
    done_testing( $config_data->{volume_count} *3 );
    
    # save yaml file, newly populated with error counts
    YAML::XS::DumpFile($config_file,$config_data);
}

# "good" package should pass all stages
sub test_all_pass{
    my ($namespace, $package_type, $objid,$source) = @_;
    my ($volume, $vol_val);
    
    # get logfile
    my ($logfile_handle, $logfile_name) = get_temp();
    $source = $all_pass_staging;    

    {
        set_config($source,'staging'=>'ingest');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::VolumeValidator->new(volume => $volume);
		$vol_val->run();
    }

    # test that we succeeded
    ok($vol_val->succeeded(), "all_pass package validation for $package_type $objid");
}

# package should pass remediation AND validation
sub test_val_pass {
	my ($namespace, $package_type, $objid, $source) = @_;
	my ($volume, $vol_val);

	# get logfile
	my ($logfile_handle, $logfile_name) = get_temp();
	$source = $val_pass_staging;

    {
        set_config($source,'staging'=>'ingest');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::VolumeValidator->new(volume => $volume);
        $vol_val->run();
    }

    # test that we succeeded
    ok($vol_val->succeeded(), "val_pass package validation for $package_type $objid");
}

#should pass remediation, but FAIL here on validation
sub test_rem_pass{
    my ($namespace, $package_type,$objid,$source,$expected_log,$fail_error_count) = @_;
    my ($volume, $vol_val);
    
    # get logfile
    my ($logfile_handle, $logfile_name) = get_temp();
	$source = $rem_pass_staging;        

	eval{
		set_config(0,'stop_on_error');
    	set_config($source,'staging'=>'ingest');
    	$volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
   		$vol_val = HTFeed::VolumeValidator->new(volume => $volume);
    	$vol_val->run();
	};

    # test number of errors
    is($vol_val->failed(),$fail_error_count,"error count for rem_pass package validation for type $package_type $objid");
 
    my $diffs = `diff $expected_log $logfile_name`;
    if ($diffs eq q{}){
        pass("error log match for rem_pass package validation for $package_type $objid");
    }
    else{
        fail("error log match for rem_pass package validation for $package_type  $objid");
        copy($logfile_name,"failure-$source-$$");
        open(my $diff_fh,">diffs--$source-$$");
        print $diff_fh $diffs;
        close($diff_fh);
    }
}

sub setup_failure{
    my ($package_type,$namespace,$objid,$source,$expected_log) = @_;
    
    my ($volume, $vol_val);
    
    # get logfile
    my ($logfile_handle, $logfile_name) = get_temp();

    # validate damaged package
    eval{
		set_config(0,'stop_on_error');
        set_config($rem_pass_staging,'staging'=>'ingest');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::VolumeValidator->new(volume => $volume);
        $vol_val->run();
    };
   	 
    # test that we failed
    ok($vol_val->failed(),"rem_pass package validation for $package_type $namespace $objid");
    
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
