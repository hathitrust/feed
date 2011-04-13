package HTFeed::PackageType::IA::ImageRemediate::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::IA::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use HTFeed::Config qw(set_config);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

my $damaged = "/htapps/test.babel/feed/t/staging/DAMAGED";
my $undamaged = "/htapps/test.babel/feed/t/staging/UNDAMAGED";

sub ImageRemediate : Test(2){
	set_config("$undamaged/download","staging"=>"download");
	my $self  = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'ImageRemediate succeeeded');
	ok($stage->stage_info(), 'stage info ok');
}

sub TestErrors : Test(1){

	set_config($damaged,"staging"=>"download");
	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $ia_id = $volume->get_ia_id();
    my $objdir = $volume->get_download_directory();
    my $scandata = "$objdir/${ia_id}_scandata.xml";

	#get bad version from "samples"
    my $samples = "$damaged/samples/ia/${ia_id}";
    my $broken_scanData = "$samples/${ia_id}_scandata.xml";
    copy($broken_scanData,$objdir) or die "copy failed: $!";

    #run the whole thing and see coverage
    ok($stage->run(), 'pass with warnings');

    #replace with standard scandata for next stage test
    my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_scandata.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";
}

1;

__END__
