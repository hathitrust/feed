use warnings;
use strict;

use YAML::XS ();
use File::Temp ();
use File::Copy;
use HTFeed::Config qw(set_config);
use Getopt::Long;
use FindBin;
use HTFeed::Volume;

use Test::More;

# get test config
my $config_file = "$FindBin::Bin/etc/package.yaml";
my $config_data = YAML::XS::LoadFile($config_file);

my $setup_mode;
GetOptions ( "s" => \$setup_mode );


my $damaged_staging = $config_data->{package_directory}->{damaged};
my $undamaged_staging = $config_data->{package_directory}->{undamaged};
my $validation_logs_dir = $config_data->{package_directory}->{undamaged};

# iterate through all volumes in config
my $package_types = $config_data->{package_types};
while( my ($package_type,$namespaces) = each %{ $package_types } ){
    while( my ($namespace,$objects) = each %{ $namespaces } ){
        foreach my $object ( @{ $objects } ){
            # get environment
            my ($objid,$fail_error_count) = @{$object};
            
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
    YAML::XS::DumpFile($config_file);
}

# test_package($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path)
sub test_success{
    my ($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path,$expected_log) = @_;
    
    my ($volume, $vol_val);
    
    # create logfile, File::Temp will unlink it automatically on DESTROY
    my $logfile_handle = File::Temp->new();
    my $logfile_name = $logfile_handle->filename;
        
    # validate undamaged package
    {
        set_config($undamaged_pkg_path,'staging'=>'download');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::VolumeValidator->new($volume);

        $vol_val->run();
    }
    
    # test that we succeeded
    ok($vol_val->succeeded(), "undamaged package validation for $package_type $namespace $objid");
}

# test_package($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path,$expected_log,$fail_error_count)
sub test_failure{
    my ($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path,$expected_log,$fail_error_count) = @_;
    
    my ($volume, $vol_val);
    
    # create logfile, File::Temp will unlink it automatically on DESTROY
    my $logfile_handle = File::Temp->new();
    my $logfile_name = $logfile_handle->filename;
        
    # validate damaged package
    {
        set_config($damaged_pkg_path,'staging'=>'download');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::VolumeValidator->new($volume);

        $vol_val->run();
    }
    
    # test number of errors
    is($vol_val->failed(),$fail_error_count,"error count for damaged package validation for $package_type $namespace $objid");
    
    my $diffs = `diff $expected_log $logfile_name`;
    if ($diffs eq q{}){
        pass("error log match for damaged package validation for $package_type $namespace $objid");
    }
    else{
        fail("error log match for damaged package validation for $package_type $namespace $objid");
    }
}

# test_package($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path,$expected_log)
sub setup_failure{
    my ($package_type,$namespace,$objid,$damaged_pkg_path,$undamaged_pkg_path,$expected_log) = @_;
    
    my ($volume, $vol_val);
    
    # create logfile, File::Temp will unlink it automatically on DESTROY
    my $logfile_handle = File::Temp->new();
    my $logfile_name = $logfile_handle->filename;
        
    # validate damaged package
    {
        set_config($damaged_pkg_path,'staging'=>'download');
        $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
        $vol_val = HTFeed::VolumeValidator->new($volume);

        $vol_val->run();
    }
    
    # test that we failed
    ok($vol_val->failed());
    
    # put error log where it belongs
    copy($logfile_name,$expected_log);
    
    # return number of errors
    return $vol_val->failed();
}
