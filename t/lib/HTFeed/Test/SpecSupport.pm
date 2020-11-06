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

our @EXPORT_OK = qw(mock_zephir stage_volume);

sub mock_zephir {

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

}

sub stage_volume {
  my $tmpdirs = shift;
  my $namespace = shift;
  my $objid = shift;

  my $mets = $tmpdirs->test_home . "/fixtures/volumes/$objid.mets.xml";
  my $zip = $tmpdirs->test_home . "/fixtures/volumes/$objid.zip";
  system("cp $mets $tmpdirs->{ingest}");
  mkdir("$tmpdirs->{zipfile}/$objid");
  system("cp $zip $tmpdirs->{zipfile}/$objid");

  my $volume = HTFeed::Volume->new(
    namespace => $namespace,
    objid => $objid,
    packagetype => 'simple');
}
