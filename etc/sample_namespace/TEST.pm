package HTFeed::Namespace::TEST;

# For testing

use base qw(HTFeed::Namespace);

# The HathiTrust namespace
our $identifier = 'test';

our $config = {
    handle_prefix => '2027/deleteme',
    packagetypes => [qw(ht ia simple kirtas epub simpledigital vendoraudio emma)],
    description => 'Test namespace',
    dropbox_folder => '/test-hathitrust-ingest',

    default_timezone => 'America/Detroit',
};

# Everything is permitted. Nothing is forbidden.
sub validate_barcode {
    return 1;
}

1;

__END__
