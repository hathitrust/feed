package HTFeed::PackageType::Yale::ImageRemediate::Test;

use warnings;
use strict;
#use base qw(HTFeed::PackageType::Yale::AbstractTest);
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Config qw(set_config);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub prep : Test(setup){
	#TODO: switch to config method in Support.pm
	set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/download','staging'=>'download');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/preingest','staging'=>'preingest');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/ingest','staging'=>'ingest');
}

sub ImageRemediate : Test(1){
    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'Yale: ImageRemediate succeeded with unbroken package');    
}

1;

__END__
