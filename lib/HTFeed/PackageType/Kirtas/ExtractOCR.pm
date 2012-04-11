package HTFeed::PackageType::Kirtas::ExtractOCR;

use warnings;
use strict;
use base qw(HTFeed::Stage);

use Log::Log4perl qw(get_logger);

=item extract_ocr()

Extracts the OCR from the ALTO coordinate OCR into text files in the target staging directory.

=cut

sub run {
    my $self = shift;
    my $volume = $self->{volume};
    my $alto_parser = new HTFeed::PackageType::Kirtas::AltoParse();
    my $mets_xc = $volume->get_kirtas_mets_xpc();
    my $objid = $volume->get_objid();
    my $stage_path = $volume->get_staging_directory();
    get_logger()->trace("Extracting OCR..");
    foreach my $alto_xml_node (
	$mets_xc->findnodes(
	    '//mets:fileGrp[@ID="ALTOGRP"]/mets:file/mets:FLocat/@xlink:href')
    )
    {
	my $alto_dospath  = $alto_xml_node->nodeValue();
	my $alto_xml_file = $volume->dospath_to_path($alto_dospath);
	$alto_dospath =~ /($objid)_(\d+)_ALTO\.xml/i;
	my $alto_txt    = lc("$1_$2.txt");
	my $alto_newxml = lc("$1_$2.xml");
	get_logger()->trace("Normalizing OCR file $alto_xml_file");

	my $fh = new IO::File(">$stage_path/$alto_txt")
	    or die("Can't open $stage_path/$alto_txt for writing: $!");
	$alto_parser->set_fh($fh);
	$alto_parser->parse_file($alto_xml_file);

	# also retain coordinate-OCR XML file
	system("dos2unix -q -n '$alto_xml_file' '$stage_path/$alto_newxml'")
	    and die("Can't copy $alto_xml_file: $?");

	$fh->close();
    }
    $volume->record_premis_event('ocr_normalize');
    $self->_set_done();
    return $self->succeeded();

}

sub stage_info{
    return {success_state => 'ocr_extracted', failure_state => ''};
}

package HTFeed::PackageType::Kirtas::AltoParse;
use XML::LibXML::SAX;
use base qw(XML::LibXML::SAX);

sub new {
    my $class = shift;
    my $self  = {};
    return bless $self, $class;
}

sub start_element {
    my ( $self, $element ) = @_;
    my $name = $element->{Name};
    $name eq 'String'
    && print { $self->{'fh'} } $element->{Attributes}{'{}CONTENT'}{Value};
    $name eq 'SP' && print { $self->{'fh'} } ' ';
    $self->SUPER::start_element($element);
}

sub end_element {
    my ( $self, $element ) = @_;
    my $name = $element->{Name};
    $name eq 'TextLine'  && print { $self->{'fh'} } "\n";
    $name eq 'TextBlock' && print { $self->{'fh'} } "\n";
    $self->SUPER::end_element($element);
}

sub set_fh {
    my $self = shift;

    # Set the output filehandle for the text parsed out of the XML
    $self->{'fh'} = shift;
    $self->{'fh'}->binmode(':utf8');
}


1;

__END__
