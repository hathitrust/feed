package HTFeed::PackageType::IA::SourceMETS::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::IA::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use HTFeed::Config qw(set_config);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

# Test SourceMETS with undamaged package
sub SourceMETS : Test(1){

	#my $config = test_config('undamaged');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/download','staging'=>'download');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/preingest','staging'=>'preingest');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/ingest','staging'=>'ingest');

	my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'IA: SourceMETS succeeded with undamaged package');
}

# Test for errors with damaged package
sub Errors : Test(1){

	#my $config = test_config('damaged');
    set_config('/htapps/test.babel/feed/t/staging/DAMAGED/','staging'=>'download');

    my $self = shift;
    my $stage = $self->{test_stage};
    my $volume = $self->{volume};
    my $ia_id = $volume->get_ia_id();
    my $objdir = $volume->get_download_directory();
    my $scandata = "$objdir/${ia_id}_scandata.xml";

    #get damaged scandata from "samples"
    my $samples = "/htapps/test.babel/feed/t/staging/DAMAGED/samples/ia/${ia_id}";
    my $broken_scanData = "$samples/${ia_id}_scandata.xml";
    copy($broken_scanData,$objdir) or die "copy failed: $!";

    # test stage with damaged $scandata
    ok( $stage->run(), 'IA: SourceMETS stage passes with errors on damaged package');

    #replace with standard scandata for next stage test
    my $clean_copy = "/htapps/test.babel/feed/t/staging/UNDAMAGED/download/ia/$ia_id/${ia_id}_scandata.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";

}

1;

__END__
