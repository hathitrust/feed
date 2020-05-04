package HTFeed::Test::SpecSupport;

use FindBin;
use lib "$FindBin::Bin/../lib";

# support for Test::Spec tests
use HTFeed;
use HTFeed::Test::Logger;

use HTFeed::Test::TempDirs;

use warnings;
use strict;
use Exporter 'import';

our @EXPORT_OK = qw(mock_premis_mets);

sub mock_premis_mets {

  # don't hit the database
  *HTFeed::Volume::record_premis_event = sub {
    1;
  };

  *HTFeed::Volume::get_sources = sub {
    return ( 'ht_test','ht_test','ht_test' );
  };

  # use faked-up marc in case it's missing

  *HTFeed::SourceMETS::_get_marc_from_zephir = sub {
    my $self = shift;
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

  *HTFeed::Volume::get_event_info = sub {
    return ("some-event-id", "2017-01-01T00:00:00-04:00", undef, undef);
  }
}
