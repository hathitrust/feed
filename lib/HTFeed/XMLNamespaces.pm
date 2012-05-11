package HTFeed::XMLNamespaces;

use strict;
use Readonly;
use Exporter;
use base qw(Exporter);

our @EXPORT_OK   = qw(register_namespaces NS_METS NS_PREMIS1 NS_PREMIS NS_MARC NS_MIX NS_JHOVE NS_XLINK NS_DC NS_XSI SCHEMA_PREMIS SCHEMA_MARC );
our %EXPORT_TAGS = ( 'namespaces' =>
      [qw(NS_METS NS_PREMIS NS_PREMIS1 NS_MARC NS_MIX NS_JHOVE NS_XLINK NS_DC NS_XSI)],
      'schemas' => 
      [qw(SCHEMA_PREMIS SCHEMA_MARC)]
  );

use constant {
    NS_DC     => 'http://purl.org/dc/elements/1.1/',
    NS_JHOVE  => 'http://hul.harvard.edu/ois/xml/ns/jhove',
    NS_MARC   => 'http://www.loc.gov/MARC21/slim',
    NS_METS   => 'http://www.loc.gov/METS/',
    NS_MIX    => 'http://www.loc.gov/mix/',
    NS_MODS   => 'http://www.loc.gov/mods/v3',
    NS_OAI_DC => 'http://www.openarchives.org/OAI/2.0/oai_dc/',
    NS_PREMIS => 'info:lc/xmlns/premis-v2',
    NS_PREMIS1 => 'http://www.loc.gov/standards/premis',
    NS_RDF    => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    NS_TIFF   => 'http://ns.adobe.com/tiff/1.0/',
    NS_XLINK  => 'http://www.w3.org/1999/xlink',
    NS_XSI    => 'http://www.w3.org/2001/XMLSchema-instance',
	NS_AES	  => 'http://www.aes.org/audioObject',
    NS_HT     => 'http://www.hathitrust.org/premis_extension'
};

use constant {
    SCHEMA_PREMIS => "http://www.loc.gov/standards/premis/v2/premis-v2-0.xsd",
    SCHEMA_MARC => "http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
};


=item register_namespaces($xpath_context)

    Registers an assortment of useful namespaces on the given XML::LibXML::XPathContext

    The registered prefixes are:

	dc, jhove, marc, mets, mix, mods, oai_dc, premis, xlink, xsi, aes

=cut

sub register_namespaces {
    my $xpc = shift;

    $xpc->registerNs( 'dc',     NS_DC );
    $xpc->registerNs( 'jhove',  NS_JHOVE );
    $xpc->registerNs( 'marc',   NS_MARC );
    $xpc->registerNs( 'mets',   NS_METS );
    $xpc->registerNs( 'mix',    NS_MIX );
    $xpc->registerNs( 'mods',   NS_MODS );
    $xpc->registerNs( 'oai_dc', NS_OAI_DC );
    $xpc->registerNs( 'premis', NS_PREMIS );
    $xpc->registerNs( 'premis1', NS_PREMIS1 );
    $xpc->registerNs( 'rdf',    NS_RDF );
    $xpc->registerNs( 'tiff',   NS_TIFF );
    $xpc->registerNs( 'xlink',  NS_XLINK );
    $xpc->registerNs( 'xsi',    NS_XSI );
	$xpc->registerNs( 'aes', 	NS_AES );
    $xpc->registerNs( 'ht',     NS_HT );

    return;
}

1;
