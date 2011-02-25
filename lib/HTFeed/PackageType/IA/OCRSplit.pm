
package HTFeed::PackageType::IA::OCRSplit;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

#
# Split the OCR file (_djvu.xml) into a TXT and an XML file for each page
#

sub run {
    my $self = shift;
    my $volume      = $self->{volume};
    my $ia_id = $volume->get_ia_id();
    my $download_directory = $volume->get_download_directory();
    my $preingest_directory = $volume->get_preingest_directory();
    my $staging_directory = $volume->mk_staging_directory($self->stage_on_disk());

    my $xml = "${ia_id}_djvu.xml";

    if ( !-e "$download_directory/$xml" ) {
        $self->set_error("MissingFile",file => $xml);
        return;
    }


    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_file("$download_directory/$xml");

    my $start = 0;


    foreach my $objnode ($doc->findnodes("/DjVuXML/BODY/OBJECT")) {
        my @objtext = ();
        my $seqnum;
        my $usemap = $objnode->getAttribute("usemap");
        if($usemap =~ /_(\d+)\./) {
            $seqnum = $1;
        } else {
            $self->set_error("BadField",field => "seqnum",actual => $usemap,
                detail=>"Can't extract sequence number");
            next;
        };
        foreach my $paragraph ($objnode->findnodes(".//PARAGRAPH")) {
            foreach my $line ($paragraph->findnodes(".//LINE")) {
                foreach my $word ($line->findnodes(".//WORD")) {
                    my $text = $word->textContent();
                    push(@objtext,$text);
                }
                push(@objtext,"\n");
            }
            push(@objtext,"\n");
        }

        # write djvu xml
        my $pagedoc = XML::LibXML::Document->new();
        $pagedoc->createInternalSubset("DjVuXML",undef,undef);
        my $rootnode = $pagedoc->createElement("DjVuXML");
        $pagedoc->setDocumentElement($rootnode);
        my $bodynode = $pagedoc->createElement("BODY");
        $rootnode->appendChild($bodynode);
        $bodynode->appendChild($objnode);


        $logger->trace("Writing OCR for $usemap");
        # write out with ignorable white space
        $pagedoc->toFile(sprintf("%s/%08d.xml",$staging_directory,$seqnum),1);


        # write text

        my $outfile_txt = sprintf( "%s/%08d.txt", $staging_directory, $seqnum );

        open(my $out, ">", $outfile_txt ) or croak ( "Can't open $outfile_txt: $!");
        binmode($out,":utf8");

        # If there was no OCR for this page, we'll just end up with a 0-byte file
        print $out join( " ", @objtext );

        close($out);

    }

    $volume->record_premis_event("ocr_normalize");

    $self->_set_done();
}

sub stage_info{
    return {success_state => 'ocr_extracted', failure_state => ''};
}
