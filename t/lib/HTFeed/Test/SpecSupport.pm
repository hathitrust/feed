package HTFeed::Test::SpecSupport;

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

# support for Test::Spec tests
use HTFeed;
use HTFeed::Test::Logger;
use HTFeed::Test::TempDirs;
use Exporter 'import';

use constant {
  # Value to pass to RabbitMQ to tell it not to block if the message queue is empty
  NO_WAIT => -1,
  # Amount of time to wait (in milliseconds) if we expect there will be a message eventually
  RECV_WAIT => 500
};

our @EXPORT_OK = qw(mock_zephir mock_clamav stage_volume NO_WAIT RECV_WAIT);

sub mock_zephir {
    no warnings 'redefine';
    *HTFeed::Volume::get_sources = sub {
        return ( 'ht_test','ht_test','ht_test' );
    };

    # use faked-up marc in case it's missing

    *HTFeed::SourceMETS::_get_marc_from_zephir = sub {
        my $self      = shift;
        my $marc_path = shift;

        open(my $fh, ">$marc_path") or die("Can't open $marc_path: $!");
        print $fh <<EOT;
<?xml version="1.0" encoding="UTF-8"?>
<collection xmlns="http://www.loc.gov/MARC21/slim">
<record>
<leader>01142cam  2200301 a 4500</leader>
</record>
</collection>
EOT

        close($fh);
    };

    use warnings 'redefine';
}

sub mock_clamav {
    use HTFeed::Test::MockClamAV;

    return HTFeed::Test::MockClamAV->new();
}

sub stage_volume {
    my $tmpdirs   = shift;
    my $namespace = shift;
    my $objid     = shift;

    my $mets = $tmpdirs->test_home . "/fixtures/volumes/$objid.mets.xml";
    my $zip  = $tmpdirs->test_home . "/fixtures/volumes/$objid.zip";

    system("cp $mets $tmpdirs->{ingest}");
    mkdir("$tmpdirs->{zipfile}/$objid");
    system("cp $zip $tmpdirs->{zipfile}/$objid");

    my $volume = HTFeed::Volume->new(
        namespace   => $namespace,
        objid       => $objid,
        packagetype => 'simple'
    );
}

1;
