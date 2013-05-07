
package HTFeed::PackageType::DLXS::OCRSplit;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);
use Carp qw(croak);

#
# Split the OCR file (_djvu.xml) into a TXT and an XML file for each page
#

sub run {
    my $self = shift;
    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $preingest_directory = $volume->get_preingest_directory();

    my $tei_hdr_file;

    if(-e "$preingest_directory/$objid.xml")  {

        open(my $xml_in, "<$preingest_directory/$objid.xml") 
            or die("Can't open $preingest_directory/$objid.xml: $!");

        my $decl;
        my $not_decl;
        while(my $line = <$xml_in>) {
            if($line =~ /^(<\?xml.*?\?>)(.*)/i) {
                if(not defined $decl) {
                    $decl = $1;
                    $not_decl .= $2;
                } else {
                    $self->set_error("BadFile", file => "$preingest_directory/$objid.xml",
                    detail => "More than one XML declaration found!");
                }
            } else {
                $not_decl .= $line;
            }

        }
        close($xml_in);

        open(my $xml_out, ">$preingest_directory/$objid.fixed.xml") 
            or die("Can't open $preingest_directory/$objid.fixed.xml: $!");
        print $xml_out $decl . "\n" if defined $decl;
        print $xml_out $not_decl;
        close($xml_out);

        $tei_hdr_file = "$preingest_directory/$objid.fixed.xml";
        $self->splinter_xml("$preingest_directory/$objid.fixed.xml");
    } elsif(-e "$preingest_directory/$objid.txt") {
        $self->splinter("$preingest_directory/$objid.txt") ;
        $tei_hdr_file = "$preingest_directory/$objid.hdr";
    } else {
        $self->set_error("MissingFile", file => "$preingest_directory/$objid.txt");
    }

    # check the encoding level:
    my $tei_xpc;
    eval {
        $tei_xpc = $volume->_parse_xpc($tei_hdr_file);
    };
    if($@ or not defined $tei_xpc) {
        $self->set_error("BadFile", file => "$preingest_directory/$objid.hdr", detail => $@);
    } else {
        my ($tei_level) = $tei_xpc->findvalue('//EDITORIALDECL/@N');
        if($tei_level ne '1') {
            $self->set_error("BadValue", field => '//EDITORIALDECL/@N', expected => "1", actual => $tei_level);
        }
    }

    $volume->record_premis_event("ocr_normalize");

    $self->_set_done();
}

sub stage_info{
    return {success_state => 'ocr_extracted', failure_state => ''};
}

## from dlxs:bin/t/text/ncr2utf8

sub ncr2utf8 {
    my $line = shift;
    $line =~ s|\&\#x([0-9a-fA-F]{1,4});|hex2utf8($1)|ges;
    $line =~ s|\&\#([0-9]{1,5});|num2utf8($1)|ges;
    return $line;
}

sub hex2utf8 
{
    my $n = shift;

    # < > & ' "
    my @hexPredefined = ( '3C', '3E', '26', '27', '22' );

    if ( grep( /^$n$/i, @hexPredefined  ) )
    {
        return '&#x' . $n . ';'; 
    }


    return num2utf8( hex( $n ) );
}

sub num2utf8
{
    my ( $t ) = @_;
    my ( $trail, $firstbits, @result );

    # < > & ' "
    my @decPredefined = ( '60', '62', '38', '39', '34' );

    if ( grep( /^$t$/, @decPredefined  ) )
    {
        return '&#x' . $t . ';'; 
    }


    if    ($t<0x00000080) { $firstbits=0x00; $trail=0; }
    elsif ($t<0x00000800) { $firstbits=0xC0; $trail=1; }
    elsif ($t<0x00010000) { $firstbits=0xE0; $trail=2; }
    elsif ($t<0x00200000) { $firstbits=0xF0; $trail=3; }
    elsif ($t<0x04000000) { $firstbits=0xF8; $trail=4; }
    elsif ($t<0x80000000) { $firstbits=0xFC; $trail=5; }
    else {
        croak "Too large scalar value, cannot be converted to UTF-8.\n";
    }
    for (1 .. $trail) 
    {
        unshift (@result, ($t & 0x3F) | 0x80);
        $t >>= 6;         # slight danger of non-portability
    }
    unshift (@result, $t | $firstbits);
    return pack ("C*", @result);
}

sub splinter_xml {
    my $self = shift;
    my $infile = shift;
    my $volume = $self->{volume};
    my $staging_directory = $volume->get_staging_directory();

    my $parser = XML::LibXML->new();
#    open(my $xml_in,"<",$infile) or croak("Can't open $xml_in: $!");
#    while(my $line = <$xml_in>) {
#        # ignore processing instructions??
#        $line =~ s/\Q<?xml version="1.0" encoding="iso-8859-1"?>\E/;
#         $parser->parse_chunk($line);
#    }
#    # finish parsing
#   my $doc = $parser->parse_chunk("",1);

    my $doc = $parser->parse_file("$infile");

    my $start = 0;


    my $seq_mapping = $volume->get_seq_mapping();
    foreach my $objnode ($doc->findnodes("//PB")) {
        my @objtext = ();
        my $seq = $objnode->getAttribute('SEQ');
        $seq = '0000' . $seq if $seq =~ /^\d{4}$/;
        if(not defined $seq or $seq !~ /^\d{8}$/) {
            $self->set_error("BadField",field => "seqnum",actual => $seq,
                detail=>"Can't extract sequence number");
            next;
        }
        push(@objtext,$objnode->getParentNode()->textContent());

        get_logger()->trace("Writing OCR for $seq");

        # write text

        my $new_seq = $seq_mapping->{$seq};
        $self->set_error("BadField",field => "seqnum", actual => $seq,
            detail => "Can't find seq in pageview.dat") if not defined $new_seq;

        my $outfile_txt = sprintf( "%s/%08d.txt", $staging_directory, $seq_mapping->{$seq} );

        open(my $out_fh, ">:utf8", $outfile_txt ) or croak ( "Can't open $outfile_txt: $!");
        # If there was no OCR for this page, we'll just end up with a 0-byte file
        print $out_fh join( " ", @objtext );
        close($out_fh);

    }
}

## from dlxs:bin/t/text/splinter

sub splinter {
    my $self = shift;
    my $infile = shift;

    my $volume = $self->{volume};
    my $staging_directory = $self->{volume}->get_staging_directory();
    my $text;
    open(my $in_fh, "<", $infile) or $self->set_error("OperationFailed",operation=>"open",file=>$infile,detail => "Could not open file: $!");
    while(my $line = <$in_fh>) {
        $text .= ncr2utf8($line);
    }
    close($in_fh);
    while ($text =~ m,<P>\s*<PB.*?SEQ="(.*?)"[^>]+>(.*?)</P>\n?,gis)
    {
        my $seq = $1;
        my $page = $2;

        my $outfile = "$staging_directory/$seq.txt";

        open( my $out_fh, '>:utf8', "$outfile" ) or $self->set_error("OperationFailed",file => $outfile,operation => "write",detail => "Could not open file: $!");
        print $out_fh $page;
        close( $out_fh);
    }
}
1;
