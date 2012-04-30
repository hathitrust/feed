package HTFeed::ModuleValidator::JPEG2000_hul;

use warnings;
use strict;

use HTFeed::ModuleValidator;
use HTFeed::XPathValidator qw(:closures);
use Scalar::Util qw(weaken);
use base qw(HTFeed::ModuleValidator);

=head1 NAME

HTFeed::ModuleValidator::JPEG2000_hil

=head1 SYNOPSIS

JPEG2000-hul HTFeed validation plugin

=cut

our $qlib = HTFeed::QueryLib::JPEG2000_hul->new();

sub _set_required_querylib {
    my $self = shift;
    $self->{qlib} = $qlib;
    return 1;
}

sub _set_validators {
    my $self = shift;
    # prevent leaking $self since the closure has an implicit reference to self..
    $self->{validators} = {
        'format' => v_eq( 'repInfo', 'format', 'JPEG 2000' ),

        'status' => v_eq( 'repInfo', 'status', 'Well-Formed and valid' ),

        'module' => v_eq( 'repInfo', 'module', 'JPEG2000-hul' ),

        'mime_type' => v_and(
            v_eq( 'repInfo', 'mimeType', 'image/jp2' ),
            v_eq( 'mix',     'mime',     'image/jp2' )
        ),

        'brand' => v_eq( 'jp2Meta', 'brand', 'jp2 ' ),

        'minor_version' => v_eq( 'jp2Meta', 'minorVersion', '0' ),

        'compatibility' => v_eq( 'jp2Meta', 'compatibility', 'jp2 ' ),

        'compression' => v_and(
            v_eq( 'mix', 'compression', '34712' ),    # JPEG 2000 compression
            v_eq( 'xmp', 'compression', '34712' )
        ),

        'orientation' => v_eq( 'xmp', 'orientation', '1' ),

        'resolution_unit' => v_eq( 'xmp', 'resUnit', '2' ),    # inches

        'resolution' => v_and(
            v_in( 'xmp', 'xRes', [ '300/1', '400/1', '500/1', '600/1' ] ),
            v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
        ),

        'layers' => v_eq( 'codingStyleDefault', 'layers', '1' ),

        'decomposition_levels' =>
          v_between( 'codingStyleDefault', 'decompositionLevels', '5', '32' ),

        'colorspace' => sub {
            my $self = shift;

            # check colorspace
            my $xmp_colorSpace = $self->_findone( "xmp", "colorSpace" );
            my $xmp_samplesPerPixel =
              $self->_findone( "xmp", "samplesPerPixel" );
            my $mix_samplesPerPixel =
              $self->_findone( "mix", "samplesPerPixel" );
            my $meta_colorSpace = $self->_findone( "jp2Meta", "colorSpace" );
            my $mix_bitsPerSample = $self->_findone( "mix", "bitsPerSample" );
            my $xmp_bitsPerSample_grey =
              $self->_findvalue( "xmp", "bitsPerSample_grey" );
            my $xmp_bitsPerSample_color =
              $self->_findvalue( "xmp", "bitsPerSample_color" );

            # Greyscale: 1 sample per pixels, 8 bits per sample
            (
                     ( "1" eq $xmp_colorSpace )
                  && ( "1"         eq $xmp_samplesPerPixel )
                  && ( "1"         eq $mix_samplesPerPixel )
                  && ( "Greyscale" eq $meta_colorSpace )
                  && ( "8"         eq $mix_bitsPerSample )
                  && ( "8"         eq $xmp_bitsPerSample_grey
                    or "8" eq $xmp_bitsPerSample_color )
              )

              # sRGB: 3 samples per pixel, each sample 8 bits
              or ( ( "2" eq $xmp_colorSpace )
                && ( "3"     eq $xmp_samplesPerPixel )
                && ( "3"     eq $mix_samplesPerPixel )
                && ( "sRGB"  eq $meta_colorSpace )
                && ( "8,8,8" eq $mix_bitsPerSample )
                && ( "888"   eq $xmp_bitsPerSample_color ) )
              or (
                $self->set_error(
                    "NotMatchedValue",
                    field  => 'colorspace',
                    actual => <<END
xmp_colorSpace\t$xmp_colorSpace
xmp_samplesPerPixel\t$xmp_samplesPerPixel
mix_samplesPerPixel\t$mix_samplesPerPixel
jp2Meta_colorSpace\t$meta_colorSpace
mix_bitsPerSample\t$mix_bitsPerSample
xmp_bitsPerSample_grey\t$xmp_bitsPerSample_grey
xmp_bitsPerSample_color\t$xmp_bitsPerSample_color
END
                ) and return
              );
        },
        'dimensions' => sub {
            my $self = shift;

            my $x1 = $self->_findone( "mix", "width" );
            my $y1 = $self->_findone( "mix", "length" );
            my $x2 = $self->_findone( "xmp", "width" );
            my $y2 = $self->_findone( "xmp", "length" );

            (        ( $x1 > 0 && $y1 > 0 && $x2 > 0 && $y2 > 0 )
                  && ( $x1 == $x2 )
                  && ( $y1 == $y2 ) )
              or $self->set_error(
                "NotMatchedValue",
                field    => 'dimensions',
                expected => 'must be consistant and nonzero',
                actual   => <<END
mix_width\t$x1
mix_length\t$y1
xmp_width\t$x2
xmp_length\t$y2
END
              );
        },
        'extract_info' => sub {
            my $self = shift;

            # check for presence, record values
            $self->_setdatetime( $self->_findone( "xmp", "dateTime" ) );
            $self->_setartist( $self->_findone( "xmp", "artist" ) );
            $self->_setdocumentname( $self->_findone( "xmp", "documentName" ) );
        },
        'camera' =>
          v_and( v_exists( 'xmp', 'make' ), v_exists( 'xmp', 'model' ) )

    };
}

sub run {
    my $self = shift;

    # open contexts
    $self->_setcontext(
        name => "root",
        xpc  => $self->{xpc}
    );
    $self->_openonecontext("repInfo");
    $self->_openonecontext("jp2Meta");
    $self->_openonecontext("codestream");
    $self->_openonecontext("codingStyleDefault");
    $self->_openonecontext("mix");

# if we already have errors, quit now, we won't get anything else out of this without usable contexts
    if ( $self->failed ) {
        return;
    }

    $self->_setupXMP;

    # make sure we have an xmp before we continue
    if ( $self->failed ) {
        return;
    }

    return $self->SUPER::run();

}

sub _setupXMP {
    my $self = shift;

    # look for uuidbox, set uuidbox context
    {

        # find all UUID boxes
        my $uuidbox_nodes = $self->_findcontexts('uuidBox');

        # check that we have a uuidbox
        my $uuidbox_cnt = $uuidbox_nodes->size();
        unless ( $uuidbox_cnt > 0 ) {

            # fail
            $self->set_error(
                'BadField',
                detail => 'UUIDBox not found',
                field  => 'xmp'
            );
            return;
        }

        my $uuidbox_node;
        my $xmps_found =
          0;    # flag if we have found it yet, we better see exactly one
                # the uuid for embedded XMP data
        my @reference_uuid = (
            -66,  122, -49,  -53,  -105, -87, 66,  -24,
            -100, 113, -103, -108, -111, -29, -81, -84
        );
        my $found_uuid;
        my $uuid_context_node_containing_xmp;
        while ( $uuidbox_node = $uuidbox_nodes->shift() ) {
            $self->_setcontext( name => 'uuidBox', node => $uuidbox_node );
            $found_uuid = $self->_findnodes( 'uuidBox', 'uuid' );

            # check size
            if ( $found_uuid->size() != 16 ) {
                $self->set_error(
                    'BadValue',
                    field  => 'xmp_uuid',
                    actual => $found_uuid,
                    detail => 'UUID size must be 16'
                );

                # punt, we won't be getting any further anyway
                return;
            }
            else {
                my $found_entry;
                my $is_xmp = 1;
                foreach my $ref_entry (@reference_uuid) {
                    $found_entry = $found_uuid->shift()->textContent();

                    # fail as needed
                    unless ( $found_entry == $ref_entry ) {

                        # found uuid that does not coorespond to XMP
                        $is_xmp = 0;    # this isn't XMP, take the flag down
                        last;
                    }
                }
                if ($is_xmp) {
                    $xmps_found++;
                    $uuid_context_node_containing_xmp = $uuidbox_node;
                }
            }
        }

        if ( $xmps_found != 1 ) {
            $self->set_error(
                'BadField',
                detail => "$xmps_found possible XMPs found, expected 1",
                field  => 'xmp'
            );
            return;
        }

        # set the uidBox context to the last uuidBox with xmp
        # if there is more than one xmp we already punted
        $self->_setcontext(
            name => 'uuidBox',
            node => $uuid_context_node_containing_xmp
        );

    }

    # we are in a (the) UUIDBox that holds the XMP now

    # extract the xmp
    my $xmp_xml = "";

    my $xml_char_nodes = $self->_findnodes( "uuidBox", "xmp" );
    my $char_node;

    while ( $char_node = $xml_char_nodes->shift() ) {
        $xmp_xml .= pack( 'c', $char_node->textContent() );
    }

    # setup xmp context
    $self->_setupXMPcontext($xmp_xml);
}


package HTFeed::QueryLib::JPEG2000_hul;
#JPEG2000-hul HTFeed query plugin

use warnings;
use strict;

use base qw(HTFeed::QueryLib);

sub new {
    my $class = shift;

    # store all queries
    my $self = {
        contexts => {
            repInfo => [ "/jhove:jhove/jhove:repInfo", "root" ],
            jp2Meta => [ "jhove:properties/jhove:property[jhove:name='JPEG2000Metadata']/jhove:values", "repInfo" ],
            codestream => [ "jhove:property[jhove:name='Codestreams']/jhove:values/jhove:property[jhove:name='Codestream']/jhove:values", "jp2Meta" ],
            codingStyleDefault => [ "jhove:property[jhove:name='CodingStyleDefault']/jhove:values", "codestream" ],
            mix => [ "jhove:property[jhove:name='NisoImageMetadata']/jhove:values/jhove:value/mix:mix", "codestream" ],
            uuidBox => [ "jhove:property[jhove:name='UUIDs']/jhove:values/jhove:property[jhove:name='UUIDBox']/jhove:values", "jp2Meta" ],
        },

        queries => {

            # top level
            repInfo => {
                format   => "jhove:format",
                status   => "jhove:status",
                module   => "jhove:sigMatch/jhove:module",
                mimeType => "jhove:mimeType",
            },

            # jp2Meta children
            jp2Meta => {
                brand => "jhove:property[jhove:name='Brand']/jhove:values/jhove:value",
                minorVersion => "jhove:property[jhove:name='MinorVersion']/jhove:values/jhove:value",
                compatibility => "jhove:property[jhove:name='Compatibility']/jhove:values/jhove:value",
                colorSpace => "jhove:property[jhove:name='ColorSpecs']/jhove:values/jhove:property[jhove:name='ColorSpec']/jhove:values/jhove:property[jhove:name='EnumCS']/jhove:values/jhove:value",
            },

            # codingStyleDefault children
            codingStyleDefault => {
                layers => "jhove:property[jhove:name='NumberOfLayers']/jhove:values/jhove:value",
                decompositionLevels => "jhove:property[jhove:name='NumberDecompositionLevels']/jhove:values/jhove:value",
                transformation => "jhove:property[jhove:name='Transformation']/jhove:values/jhove:value",
            },

            # mix children
            mix => {
                mime => "mix:BasicImageParameters/mix:Format/mix:MIMEType",
                compression => "mix:BasicImageParameters/mix:Format/mix:Compression/mix:CompressionScheme",
                width => "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageWidth",
                length => "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageLength",
                bitsPerSample => "mix:ImagingPerformanceAssessment/mix:Energetics/mix:BitsPerSample",
                samplesPerPixel => "mix:ImagingPerformanceAssessment/mix:Energetics/mix:SamplesPerPixel",
            },

            # uuidBox children
            uuidBox => {
                xmp => "jhove:property[jhove:name='Data']/jhove:values/jhove:value" ,    # XMP text
                uuid => "jhove:property[jhove:name='UUID']/jhove:values/jhove:value" ,    # holds identifyer accompanying an XMP field
            },

            # XMP children
            xmp => {
                width               => "//tiff:ImageWidth",
                length              => "//tiff:ImageLength",
                bitsPerSample_grey  => "//tiff:BitsPerSample//*[not(*)] | //tiff:BitsPerSample[not(*)]",
                bitsPerSample_color => "//tiff:BitsPerSample//*[not(*)] | //tiff:BitsPerSample[not(*)]",
                compression         => "//tiff:Compression",
                colorSpace          => "//tiff:PhotometricInterpretation",
                orientation         => "//tiff:Orientation",
                samplesPerPixel     => "//tiff:SamplesPerPixel",
                xRes                => "//tiff:XResolution",
                yRes                => "//tiff:YResolution",
                resUnit             => "//tiff:ResolutionUnit",
                dateTime            => "//tiff:DateTime",
                artist              => "//tiff:Artist",
                make                => "//tiff:Make",
                model               => "//tiff:Model",
                documentName        => "//dc:source",
            },
        },
    };

    bless( $self, $class );

    _compile $self;

    return $self;
}

1;

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
