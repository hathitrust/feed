package HTFeed::ModuleValidator::TIFF_hul;

use warnings;
use strict;

use HTFeed::ModuleValidator;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::ModuleValidator);

require HTFeed::QueryLib::TIFF_hul;
our $qlib = HTFeed::QueryLib::TIFF_hul->new();

=info
	TIFF-hul HTFeed validation plugin
=cut

sub _set_required_querylib {
    my $self = shift;
    $self->{qlib} = $qlib;
    return 1;
}

sub _set_validators {
    my $self = shift;
    $self->{validators} = {
        'format' => v_eq( 'repInfo', 'format', 'TIFF' ),

        'status' => v_eq( 'repInfo', 'status', 'Well-Formed and valid' ),

        'module' => v_eq( 'repInfo', 'module', 'TIFF-hul' ),

        'mime_type' => v_and(
            v_eq( 'mix',     'mime',     'image/tiff' ),
            v_eq( 'repInfo', 'mimeType', 'image/tiff' )
        ),

        'compression' => v_eq( 'mix', 'compression', '4' ),    # CCITT Group 4

        'colorspace' => v_eq( 'mix', 'colorSpace', '0' ),      # WhiteIsZero

        'orientation' => v_eq( 'mix', 'orientation', '1' ),  # Horizontal/normal

        'resolution' =>
          v_and( v_eq( 'mix', 'xRes', '600' ), v_eq( 'mix', 'yRes', '600' ) ),

        'resolution_unit' => v_eq( 'mix', 'resUnit', '2' ),

        'bits_per_sample' => v_eq( 'mix', 'bitsPerSample', '1' ),

        'samples_per_pixel' => v_eq( 'mix', 'samplesPerPixel', '1' ),

        'dimensions' =>
          v_and( v_gt( 'mix', 'length', '1' ), v_gt( 'mix', 'width', '1' ) ),

        'extract_info' => sub {
            my $self = shift;

            # check/save useful info
            $self->_setdatetime( $self->_findone( "mix", "dateTime" ) );
            $self->_setartist( $self->_findone( "mix", "artist" ) );
            $self->_setdocumentname(
                $self->_findone( "tiffMeta", "documentName" ) );
        },

        'xmp' => sub {
            my $self = shift;

            # find xmp
            my $xmp_found = 1;
            my $xmp_xml = $self->_findxmp() or $xmp_found = 0;

            if ($xmp_found) {

                # setup xmp context
                $self->_setupXMPcontext($xmp_xml) or return 0;

             # require XMP headers to exist and match TIFF headers if XMP exists
                foreach my $field (
                    qw(bitsPerSample compression colorSpace orientation samplesPerPixel resUnit length
                    width dateTime artist documentName)
                  )
                {
                    $self->_require_same( 'mix', $field, 'xmp', $field );
                }

                # mix lists as just '600'
                $self->_validateone( "xmp", "xRes", "600/1" );
                $self->_validateone( "xmp", "yRes", "600/1" );

                # just require that they're there
                $self->_findonenode( "xmp", "make" );
                $self->_findonenode( "xmp", "model" );

            }
          }

    };
}

sub run {
    my $self = shift;

    # TODO: do this automatically
    # open contexts or fail
    $self->_setcontext(
        name => "repInfo",
        node => $self->{node},
        xpc  => $self->{xpc}
    );

    $self->_openonecontext("tiffMeta") or return;
    $self->_openonecontext("mix")      or return;

    return $self->SUPER::run();

}

sub _findxmp {
    my $self     = shift;
    my $nodelist = $self->_findnodes( "tiffMeta", "xmp" );
    my $count    = $nodelist->size();
    unless ($count) { return; }
    if ( $count > 1 ) {
        $self->_set_error("$count XMPs found zero or one expected");
        return;
    }
    my $retstring = $self->_findone( "tiffMeta", "xmp" );
    return $retstring;
}

1;

__END__;
