package HTFeed::PackageType::IA::ImageRemediate::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::IA::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use HTFeed::Config qw(set_config);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

# Run ImageRemediate on undamaged package
sub ImageRemediate : Test(2){

	#my $config = test_config('undamaged');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/download','staging'=>'download');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/ingest','staging'=>'ingest');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/preingest','staging'=>'preingest');

	my $self  = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'IA: ImageRemediate succeeeded with undamaged package');
	ok($stage->stage_info(), 'IA: ImageRemediate stage info succeeded with undamaged package');
}

# Test error handling with damaged package
sub TestErrors : Test(1){

	#my $config = test_config('damaged');
    set_config('/htapps/test.babel/feed/t/staging/DAMAGED/','staging'=>'download');

	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $ia_id = $volume->get_ia_id();
    my $objdir = $volume->get_download_directory();
    my $scandata = "$objdir/${ia_id}_scandata.xml";

	#get damaged version from "samples"
    my $samples = "/htapps/test.babel/feed/t/staging/DAMAGED/samples/ia/${ia_id}";
    my $broken_scanData = "$samples/${ia_id}_scandata.xml";
    copy($broken_scanData,$objdir) or die "copy failed: $!";

	#run the stage again with damaged package
    # TODO: build additional tests to verify damaged state
    # coverage confirms branches are tested
    ok($stage->run(), 'pass with warnings');

    #replace with standard package for next stage test
    my $clean_copy = "/htapps/test.babel/feed/t/staging/UNDAMAGED/download/ia/$ia_id/${ia_id}_scandata.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";
}

1;

__END__
