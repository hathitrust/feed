package HTFeed::PackageType::Yale::SourceMETS::Test;

use warnings;
use strict;
#use base qw(HTFeed::PackageType::Yale::AbstractTest);
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Config qw(set_config);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use File::Path qw(make_path);
use Test::More;

sub SourceMETS : Test(1){

	#TODO: switch to config method in Support.pm
	set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/download','staging'=>'download');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/preingest','staging'=>'preingest');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/ingest','staging'=>'ingest');

    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'Yale: SourceMETS succeeded with undamaged package');    
}

1;

__END__
