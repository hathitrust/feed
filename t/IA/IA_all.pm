#!/usr/bin/perl
package IA_all;

use base qw(Test::Class);
use Test::More;
use HTFeed::Config qw(set_config);
use HTFeed::Volume;
use Test::Class;
use HTFeed::PackageType::IA::Download;
use HTFeed::PackageType::IA::VerifyManifest;
use HTFeed::PackageType::IA::Unpack;
use HTFeed::PackageType::IA::DeleteCheck;
use HTFeed::PackageType::IA::OCRSplit;
use HTFeed::PackageType::IA::ImageRemediate;
use HTFeed::PackageType::IA::SourceMETS;
#use Setup;

#TODO add config data when ready to test
#get info from Setup.pm
my $path = "/htapps/ezbrooks.babel/sandbox/IA";
my $objid="ark:/13960/t00000234";
my $namespace="uc2";
my $package_type="ia";

set_config($path,'staging'=>'ingest');

sub getVol : Test(setup) {
        my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $package_type);
		shift->{volume} = $volume;
}

sub Download : Test(1) {
		my $volume = shift->{volume};
        my $vol_val = HTFeed::PackageType::IA::Download->new(volume => $volume);
        $vol_val->run();
		ok($vol_val->succeeded(), "Download for $package_type $namespace $objid");
};


sub Verify : Test(1) {
		my $volume = shift->{volume};
        my $vol_val = HTFeed::PackageType::IA::VerifyManifest->new(volume => $volume);
        $vol_val->run();
		ok($vol_val->succeeded(), "VerifyManifest for $package_type $namespace $objid");
};


sub Unpack : Test(1) {
		my $volume = shift->{volume};
        my $vol_val = HTFeed::PackageType::IA::Unpack->new(volume => $volume);
        $vol_val->run();
		ok($vol_val->succeeded(), "Unpack for $package_type $namespace $objid");
};


sub Delete : Test(1) {
		my $volume = shift->{volume};
        my $vol_val = HTFeed::PackageType::IA::DeleteCheck->new(volume => $volume);
        $vol_val->run();
		ok($vol_val->succeeded(), "DeleteCheck for $package_type $namespace $objid");
};


#sub OCRSplit : Test(1) {
#		my $volume = shift->{volume};
#        my $vol_val = HTFeed::PackageType::IA::OCRSplit->new(volume => $volume);
#        $vol_val->run();
#		ok($vol_val->succeeded(), "DeleteCheck for $package_type $namespace $objid");
#};


#sub Remediate : Test(1) {
#		my $volume = shift->{volume};
#        my $vol_val = HTFeed::PackageType::IA::ImageRemediate->new(volume => $volume);
#        $vol_val->run();
#		ok($vol_val->succeeded(), "ImageRemediate for $package_type $namespace $objid");
#};


#sub SourceMETS : Test(1) {
#		my $volume = shift->{volume};
#        my $vol_val = HTFeed::PackageType::IA::SourceMETS->new(volume => $volume);
#        $vol_val->run();
#		ok($vol_val->succeeded(), "DeleteCheck for $package_type $namespace $objid");
#};

done_testing();
