package HTFeed::Namespace::TEST;

# For testing

use base qw(HTFeed::Namespace);

# The HathiTrust namespace
our $identifier = 'test';

our $config = {
    grinid           => "TEST",
    handle_prefix    => '2027/deleteme',
    packagetypes     => [qw(ht ia simple epub simpledigital emma google)],
    description      => 'Test namespace',
    dropbox_folder   => '/test-hathitrust-ingest',
    default_timezone => 'America/Detroit',
};

# Everything is OK except a test invalid barcode
sub validate_barcode {
    my $self    = shift;
    my $barcode = shift;

    return ($barcode ne 'invalid');
}

1;
