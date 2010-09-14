package HTFeed::Namespaces;

use strict;
use Readonly;
use base qw(Exporter);

our @EXPORT_OK   = qw(register_namespaces);
our %EXPORT_TAGS = ( 'namespaces' =>
      qw(NS_METS NS_PREMIS NS_MARC NS_MIX NS_JHOVE NS_XLINK NS_DC NS_XSI) );

use constant {
    NS_DC     => 'http://purl.org/dc/elements/1.1/',
    NS_JHOVE  => 'http://hul.harvard.edu/ois/xml/ns/jhove',
    NS_MARC   => 'http://www.loc.gov/MARC21/slim',
    NS_METS   => 'http://www.loc.gov/METS/',
    NS_MIX    => 'http://www.loc.gov/mix/v10',
    NS_MODS   => 'http://www.loc.gov/mods/v3',
    NS_OAI_DC => 'http://www.openarchives.org/OAI/2.0/oai_dc/',
    NS_PREMIS => 'info:lc/xmlns/premis-v2',
    NS_XLINK  => 'http://www.w3.org/1999/xlink',
    NS_XSI    => 'http://www.w3.org/2001/XMLSchema-instance'
};

=item register_namespaces($xpath_context)

    Registers an assortment of useful namespaces on the given XML::LibXML::XPathContext

    The registered prefixes are:

	dc, jhove, marc, mets, mix, mods, oai_dc, premis, xlink, xsi

=cut

sub register_namespaces($) {
    my $xpc = shift;

    $xpc->registerNs( 'dc',     NS_DC );
    $xpc->registerNs( 'jhove',  NS_JHOVE );
    $xpc->registerNs( 'marc',   NS_MARC );
    $xpc->registerNs( 'mets',   NS_METS );
    $xpc->registerNs( 'mix',    NS_MIX );
    $xpc->registerNs( 'mods',   NS_MODS );
    $xpc->registerNs( 'oai_dc', NS_OAI_DC );
    $xpc->registerNs( 'premis', NS_PREMIS );
    $xpc->registerNs( 'xlink',  NS_XLINK );
    $xpc->registerNs( 'xsi',    NS_XSI );

    return;
}

1;
