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
                    qw(bitsPerSample compression colorSpace orientation samplesPerPixel resUnit length width artist )
                  )
                {
                    $self->_require_same( 'mix', $field, 'xmp', $field );
                }
                $self->_require_same( 'tiffMeta', 'documentName', 'xmp',
                    'documentName' );

                my $xmp_datetime = $self->_findone( "xmp", "dateTime" );
                my $mix_datetime = $self->_findone( "mix", "dateTime" );

                # xmp has timezone, mix doesn't..
                if ( $xmp_datetime !~ /^\Q$mix_datetime\E(\+\d{2}:\d{2})?/ ) {
                    $self->set_error(
                        "NotMatchedValue",
                        field  => 'dateTime',
                        actual => {
                            xmp_datetime => $xmp_datetime,
                            mix_datetime => $mix_datetime
                        }
                    );
                }

                # mix lists as just '600', XMP lists as '600/1'
                my $xres = $self->_findonenode( "xmp", "xRes" );
                if ( my $xres = /^(\d+)\/1$/ ) {
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

                $self->_validateone( "xmp", "xRes", "600/1" );
                $self->_require_same( "xmp", "xRes", "xmp", "yRes" );

            }
          },

          'camera' => sub {
            my $self = shift;

            # find xmp
            my $xmp_found = 1;
            my $xmp_xml = $self->_findxmp() or $xmp_found = 0;

            if ($xmp_found) {

                # setup xmp context
                $self->_setupXMPcontext($xmp_xml) or return 0;

                # Optional??
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
        name => "root",
        xpc  => $self->{xpc}
    );
    $self->_openonecontext("repInfo")  or return;
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
        $self->set_error(
            "BadField",
            detail => "$count XMPs found zero or one expected",
            field  => 'xmp'
        );
        return;
    }
    my $retstring = $self->_findone( "tiffMeta", "xmp" );
    return $retstring;
}

1;

__END__;
