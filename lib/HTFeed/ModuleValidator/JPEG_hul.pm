package HTFeed::ModuleValidator::JPEG_hul;

use warnings;
use strict;

use HTFeed::ModuleValidator;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::ModuleValidator);

require HTFeed::QueryLib::JPEG_hul;
our $qlib = HTFeed::QueryLib::JPEG_hul->new();

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
        'format' => v_eq( 'repInfo', 'format', 'JPEG' ),

        'status' => v_eq( 'repInfo', 'status', 'Well-Formed and valid' ),

        'module' => v_eq( 'repInfo', 'module', 'JPEG-hul' ),

        'profile' => v_eq( 'repInfo', 'profile', 'JFIF' ),

        'mime_type' => v_and(
            v_eq( 'mix',     'mime',     'image/jpeg' ),
            v_eq( 'repInfo', 'mimeType', 'image/jpeg' )
        ),

        'compression' => v_and(
            v_eq( 'mix', 'compression', '6' ),    # JPEG
            v_eq( 'xmp', 'compression', '6' )
        ),

        'colorspace' => v_and(
            v_eq( 'mix', 'colorSpace', '6' ),     # YCbCr
            v_eq( 'xmp', 'colorSpace', '6' )
        ),

        'orientation' => v_eq( 'xmp', 'orientation', '1' ),  # Horizontal/normal

        'resolution' => v_and(
            v_eq( 'mix', 'xRes', '300' ),
            v_same( 'mix', 'yRes', 'mix', 'xRes' ),
            v_same( 'xmp', 'xRes', 'mix', 'xRes' ),
            v_same( 'xmp', 'yRes', 'mix', 'xRes' ),
        ),

        'xmp_resolution' => sub {
            my $self = shift;
            # mix lists as just '600', XMP lists as '600/1'
            my $xres = $self->_findone( "xmp", "xRes" );
            if ( $xres =~ /^(\d+)\/1$/ ) {
                $self->_validateone( "mix", "xRes", $1 );
            }
            else {
                $self->set_error(
                    "BadValue",
                    field  => "xmp_xRes",
                    actual => "$xres",
                    detail => "Should be in format NNN/1"
                );
            }

            $self->_require_same( "xmp", "xRes", "xmp", "yRes" );
        },


        'resolution_unit' =>
          v_and( v_eq( 'mix', 'resUnit', '2' ), v_eq( 'xmp', 'resUnit', '2' ) ),

        'bits_per_sample' => v_and(
            v_eq( 'mix', 'bitsPerSample', '8,8,8' ),
            v_eq( 'xmp', 'bitsPerSample', '888')
        ),

        'samples_per_pixel' => v_and(
            v_eq( 'mix', 'samplesPerPixel', '3' ),
            v_eq( 'xmp', 'samplesPerPixel', '3' )
        ),

        'dimensions' => v_and(
            v_gt( 'mix', 'length', '1' ),
            v_gt( 'mix', 'width',  '1' ),
            v_same( 'mix', 'length', 'xmp', 'length' ),
            v_same( 'mix', 'width',  'xmp', 'width' )
        ),

        'extract_info' => sub {
            my $self = shift;

            # check/save useful info
            $self->_setdatetime( $self->_findone( "xmp", "dateTime" ) );
            $self->_setartist( $self->_findone( "mix", "artist" ) );
            $self->_require_same( "mix", "artist", "xmp", "artist" );
            $self->_setdocumentname( $self->_findone( "xmp", "documentName" ) );
        },

        'camera' =>
          v_and( v_exists( 'xmp', 'make' ), v_exists( 'xmp', 'model' ) )

    };
}

sub run {
    my $self = shift;

    # TODO: do this automatically
    # open contexts or fail
    $self->_setcontext(
        name => "root",
        xpc  => $self->{xpc}
    );
    $self->_openonecontext("repInfo")   or return;
    $self->_openonecontext("imageMeta") or return;
    $self->_openonecontext("mix")       or return;

    my $xmp_xml = $self->_findone( "imageMeta", "xmp" );
    $self->_setupXMPcontext($xmp_xml) or return;

    return $self->SUPER::run();

}

sub _findxmp {
    my $self = shift;
    return 1;
}

1;

__END__;
