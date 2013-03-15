package HTFeed::PackageType::Google::Unpack::Test;

use warnings;
use strict;

use base qw(HTFeed::Stage::AbstractTest);
use Test::More;

use HTFeed::Test::Support qw(md5_dir);

sub run_google_unpack : Test(2){
    my $self = shift;
    
    my $stage = $self->{test_stage};

	#TODO check this
    ok($stage->run(),'Unpack google SIP');

    my $md5_found = md5_dir($stage->{volume}->get_staging_directory());
    my $md5_expected = q(d41d8cd98f00b204e9800998ecf8427e);

    is ($md5_found,$md5_expected, 'Checksum unpacked google SIP');
}

1;

__END__
