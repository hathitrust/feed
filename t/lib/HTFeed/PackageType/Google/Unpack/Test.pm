package HTFeed::PackageType::Google::Unpack::Test;

use warnings;
use strict;

use base qw(HTFeed::Stage::AbstractTest);
use Test::More;

use HTFeed::Test::Support qw(md5_dir);

sub run_google_unpack : Test(2){
    my $self = shift;
    
    my $stage = $self->{test_stage};

    ok($stage->run(),'Unpack google SIP');
    my $md5_found = md5_dir($stage->{volume}->get_staging_directory());
    my $md5_expected = q(a823e934d11c61918a55bbc62fe26745);

    is ($md5_expected, $md5_found, 'Checksum unpacked google SIP');
}

1;

__END__
