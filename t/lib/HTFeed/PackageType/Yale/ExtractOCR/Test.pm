package HTFeed::PackageType::Yale::ExtractOCR::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::Yale::AbstractTest);
use HTFeed::Config qw(set_config);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub ExtractOCR : Test(2){

	#TODO: use config method in Test/Support.pm
	set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/download','staging'=>'download');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/preingest','staging'=>'preingest');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/ingest','staging'=>'ingest');

    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'Yale: ExtractOCR succeeded with undamaged pacakge');
	ok($stage->stage_info(), 'Yale: ExtractOCR stage info returned for unbroken package');
}

1;

__END__
