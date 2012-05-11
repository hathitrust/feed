#!/usr/bin/perl

package HTFeed::PackageType::DLXS::VolumeValidator;

use base qw(HTFeed::VolumeValidator);
use File::Basename;
use HTFeed::XMLNamespaces qw(register_namespaces);

use strict;

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    $self->{stages}{validate_consistency} =  \&_validate_consistency;

    return $self;

}

sub _validate_consistency {
    my $self   = shift;
    $self->SUPER::_validate_consistency(@_);

    my $volume = $self->{volume};

    my $files = $volume->get_required_file_groups_by_page();

    # TODO: query PREMIS events for item to make sure any sequence gaps are listed there.
    # <HT:fileList xmlns:HT="http://www.hathitrust.org/premis_extension" status="removed"><HT:file>00000001.tif</HT:file><HT:file>00000001.txt</HT:file></HT:fileList>

    my (undef,undef,$outcome) = $volume->get_event_info('target_remove');
    my @allowed_missing_seq = ();
    if($outcome) {
        my $xpc = XML::LibXML::XPathContext->new($outcome);
        register_namespaces($xpc);
        @allowed_missing_seq = map { basename($_->toString(),".txt",".tif",".jp2") } 
            $xpc->findnodes("//ht:fileList[\@status='removed']/ht:file/text()");
    }

    my $prev_sequence_number = 0;
    my @sequence_numbers     = sort( keys(%$files) );
    foreach my $sequence_number (@sequence_numbers) {
        for(my $i = $prev_sequence_number + 1; $i < $sequence_number; $i++) {
                # anything in this range is missing
                if( ! grep { $_ == $i } @allowed_missing_seq ) {
                $self->set_error( "MissingFile",
                    detail =>
                    "Skip sequence number from $prev_sequence_number to $sequence_number"
                );
            }
        }
        $prev_sequence_number = $sequence_number;
    }
    

    # Make sure that every jp2 has a corresponding TIFF.
    while ( my ( $sequence_number, $files ) = each( %{$files} ) ) {
        my $has_jp2 = 0;
        my $has_tif = 0;
        foreach my $file (@{$files->{image}}) {
            $has_jp2++ if($file =~ /\.jp2$/);
            $has_tif++ if($file =~ /\.tif$/);
        }
        if($has_jp2 and !$has_tif) {
            $self->set_error("MissingFile",file => "$sequence_number.tif",
                detail => "JP2 for seq=$sequence_number exists but TIFF does not.")
        }
    }
}


1;
