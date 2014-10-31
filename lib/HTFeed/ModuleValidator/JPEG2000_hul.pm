package HTFeed::ModuleValidator::JPEG2000_hul;

use warnings;
use strict;

use HTFeed::ModuleValidator;
use HTFeed::XPathValidator qw(:closures);
use Scalar::Util qw(weaken);
use Log::Log4perl qw(get_logger);
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
        'format' => {
            desc  => "Baseline JPEG 2000 format",
            valid => v_eq( 'repInfo', 'format', 'JPEG 2000' ),
            detail =>
'This checks that JHOVE properly identified your image as being in the JPEG2000 format. If it failed, your image may not be a JPEG2000 image. If it can be opened with an image editor or viewer, try converting it to JPEG2000 image. If the image cannot be opened, it is likely severely corrupted and should be rescanned or regenerated from the source image.'
        },

        'status' => {
            desc  => "JHOVE status",
            valid => v_eq( 'repInfo', 'status', 'Well-Formed and valid' ),
            detail =>
'This checks that the JPEG2000 is well-formed and valid according to the JPEG2000 specification. It may be possible to remediate the image if it is well-formed but not valid. Malformed JPEG2000s most likely will need to be regenerated from the source image.'
        },

        'module' => {
            desc  => "JHOVE reporting module",
            valid => v_eq( 'repInfo', 'module', 'JPEG2000-hul' ),
            detail =>
'This checks that JHOVE used its JPEG2000 plugin to extract metadata from the image. That should always be the case, so please send a bug report if you see this message.'
        },

        'mime_type' => {
            desc  => "MIME type",
            valid => v_eq( 'repInfo', 'mimeType', 'image/jp2' ),
            detail =>
'This checks that JHOVE is reporting the images have the proper MIME type. If this check fails, the image may be in an incorrect format and likely will need to be regenerated from the source image.'
        },

        'brand' => {
            desc  => "JPEG2000 brand",
            valid => v_eq( 'jp2Meta', 'brand', 'jp2 ' ),
            detail =>
'This checks that the JPEG2000 image uses only features from Part 1 of the JPEG2000 specification. If this value is "jpx" or "jpf", the image uses features from Part 2 of the JPEG2000 specifications and cannot be supported in HathiTrust. Notably, recent versions of Photoshop with native JPEG2000 support are incapable of creating a JPEG2000 image that passes this check.'
        },

        'minor_version' => {
            desc  => "JPEG2000 minor version",
            valid => v_eq( 'jp2Meta', 'minorVersion', '0' ),
            detail =>
'This checks that the JPEG2000 image matches the expected version of the JPEG2000 standard. If this check fails, please send a bug report with additional details about how the JPEG2000 image was generated.'
        },

        'compatibility' => {
            desc  => "JPEG2000 compatibility",
            valid => v_eq( 'jp2Meta', 'compatibility', 'jp2 ' ),
            detail =>
'This checks that the JPEG2000 image is compatible with Part 1 of the JPEG2000 specification. If this check fails, likely the image uses features from Part 2 of the JPEG2000 specification and will need to be regenerated from the source image.'
        },

        'compression' => {
            desc  => "JPEG2000 compression",
            valid => v_and(
                v_eq( 'mix', 'compression', 'Unknown' ),   # JPEG 2000 compression
                v_eq( 'xmp', 'compression', '34712' ),
            ),
            detail =>
'This checks that the JPEG2000 image is actually compressed with JPEG2000 compression. If the XMP metadata is incorrect it can be remediated. If the JPEG2000 compression header does not report that the image uses JPEG2000 compression, the image is likely severely corrupted and will need to be regenerated from the source image'

        },

        'orientation' => {
            desc  => "image orientation",
            valid => v_eq( 'xmp', 'orientation', '1' ),
            detail =>
'This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this value will automatically be set to 1 (normal) upon ingest to HathiTrust. The image should be rotated as needed before submiission.'
        },

        'resolution_unit' => {
            desc  => "resolution unit",
            valid => v_eq( 'xmp', 'resUnit', '2' ),
            detail =>
'This checks that the resolution unit is present set to 2 (inches). If not, this can be remediated by setting the resolution unit to 2 (inches) and adding or updating the XResolution and YResolution fields as needed.'
        },    # inches

        'resolution' => {
            desc  => "resolution",
            valid => v_and(
                v_in( 'xmp', 'xRes', [ '300/1', '400/1', '500/1', '600/1' ] ),
                v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
            ),
            detail =>
'This checks that the image has square pixels and is scanned at a resolution of at least 300 pixels per inch. If the value is missing or does not reflect the actual image resolution, this will automatically be corrected if the value is known, either through another JPEG2000 resolution header or from a supplied meta.yml file. If the resolution information is present, correct, and not equivalent to 300 or more pixels per inch (e.g. 118 pixels per centimeter) the image will need to be rescanned or regenerated from a higher-resolution master image.'
        },

        'layers' => {
            desc  => "number of quality layers",
            valid => v_eq( 'codingStyleDefault', 'layers', '1' ),
            detail =>
'This checks that the number of different "quality layers" in the JPEG2000 image (for progressive loading or faster display at lower resolution) is set to the expected value. This should be consistent between the various images in the deposit.'
        },

        'decomposition_levels' => {
            desc  => "number of decomposition levels",
            valid => v_between(
                'codingStyleDefault', 'decompositionLevels', '5', '32'
            ),
            detail =>
'This checks that the JPEG2000 image was created with the expected number of decomposition levels.'
        },

        'colorspace' =>

          {
            desc  => "validity and consistency of color space & sample depth",
            valid => sub {
                my $self = shift;

                # check colorspace
                my $xmp_colorSpace = $self->_findone( "xmp", "colorSpace" );
                my $xmp_samplesPerPixel =
                  $self->_findone( "xmp", "samplesPerPixel" );
                my $mix_samplesPerPixel =
                  $self->_findone( "mix", "samplesPerPixel" );
                my $meta_colorSpace =
                  $self->_findone( "jp2Meta", "colorSpace" );
                my $mix_bitsPerSample =
                  $self->_findvalue( "mix", "bitsPerSample" );
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
                    && ( "888"   eq $mix_bitsPerSample )
                    && ( "888"   eq $xmp_bitsPerSample_color ) )
                  or (
                    $self->set_error(
                        "NotMatchedValue",
                        field  => 'color space / bits per sample / samples per pixel',
                        remediable => 2,
                        actual => "XMP metadata: tiff:PhotometricInterpretation=$xmp_colorSpace, tiff:samplesPerPixel=$xmp_samplesPerPixel, tiff:BitsPerSample=$xmp_bitsPerSample_color; JHOVE output: JPEG2000 EnumCS=$meta_colorSpace SamplesPerPixel=$mix_samplesPerPixel BitsPerSample=$mix_bitsPerSample"
                    )
                    and return
                  );
            },
            detail =>
'This checks that greyscale JPEG2000 images are have one sample per pixel and 8 bits per sample and that full color images have three samples per pixel (one each for RGB) and 8 bits per sample. It also checks that the baseline JPEG2000 metadata is consistent with the XMP metadata. JPEG2000 images with 16 bits per sample (e.g. 48 bit color depth), alpha channels, embedded ICC color profiles, etc, are not supported. If the image itself is correct but the XMP metadata is wrong or missing, this metadata will automatically be corrected.'
          },
        'dimensions' => {
            desc  => "consistency of image dimensions",
            valid => sub {
                my $self = shift;

                my $x1 = $self->_findone( "mix", "width" );
                my $y1 = $self->_findone( "mix", "length" );
                my $x2 = $self->_findone( "xmp", "width" );
                my $y2 = $self->_findone( "xmp", "length" );

                unless (        ( $x1 > 0 && $y1 > 0 && $x2 > 0 && $y2 > 0 )
                      && ( $x1 == $x2 )
                      && ( $y1 == $y2 ) ) {

                      $x1 = '(missing)' unless defined $x1;
                      $x2 = '(missing)' unless defined $x2;
                      $y1 = '(missing)' unless defined $y1;
                      $y2 = '(missing)' unless defined $y2;
                  $self->set_error(
                    "NotMatchedValue",
                    field    => 'dimensions',
                    remediable => 2,
                    expected => 'consistant and nonzero',
                    actual   => <<END
JPEG2000 ImageWidth $x1
JPEG2000 ImageLength $y1
XMP tiff:imageWidth $x2
XMP tiff:imageLength $y2
END
                );
                }
            },
            detail =>
'This checks that the JPEG2000 image has nonzero dimensions and that the XMP metadata is present and properly reports the image dimensions. The XMP metadata will automatically be added or corrected if needed.'
        },
        'extract_info' => {
            desc  => "extract creation date, artist, document name",
            valid => sub {
                my $self = shift;

                # check for presence, record values
                $self->_setdatetime( $self->_findone( "xmp", "dateTime" ) );
                $self->_setartist( $self->_findone( "xmp", "artist" ) );
                $self->_setdocumentname(
                    $self->_findone( "xmp", "documentName" ) );
            },
            detail =>
'This checks that the image has creation date and scanning artist metadata as well as that it properly embeds its own source volume and filename. If not, these fields can be remediated if appropriate information is supplied in meta.yml.'
        },
        'camera' => {
            desc => "scanner make and model",
            valid =>
              v_and( v_exists( 'xmp', 'make' ), v_exists( 'xmp', 'model' ) ),
            detail =>
    'This checks that the image contains information about the make and model of scanner or camera used to create it. This information is optional but can be automatically added if supplied in meta.yml.'
        },
        'transformation' => {
            desc => 'JPEG2000 transformation',
            valid => v_eq('codingStyleDefault','transformation','0'),
            detail => 'HathiTrust normally expects lossy-compressed JPEG2000 images. If it is compressed losslessly, it can be recompressed, but HathiTrust will not do this automatically.'
        }

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

    if(!$self->_setupXMP) {
            get_logger( ref($self) ) ->warn("Validation failed",
                objid     => $self->{volume_id},
                namespace => $self->{volume}->get_namespace(),
                file      => $self->{filename},
                field     => 'extract XMP',
                detail    => "This attempts to find and extract the XMP XML metadata embedded in the JPEG2000 image. This will automatically be added if needed at ingest time. Since the XMP is missing, all metadata values that are stored in the XMP will be missing, and a large number of validation errors will follow."
            );
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
                detail => 'JPEG2000 image appears to be entirely missing XMP',
                remediable => 1,
                field  => 'XMP metadata'
            );
            return 0;
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
                    field  => 'JPEG 2000 UUID box',
                    remediable => 1,
                    actual => $found_uuid,
                    detail => 'UUID size must be 16'
                );

                # punt, we won't be getting any further anyway
                return 0;
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
                remediable => 1,
                field  => 'XMP'
            );
            return 0;
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

    return 1;
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
            repInfo => {
                desc   => 'JHOVE',
                query  => "/jhove:jhove/jhove:repInfo",
                parent => "root"
            },
            jp2Meta => {
                desc => 'JHOVE JPEG2000 Metadata',
                query =>
"jhove:properties/jhove:property[jhove:name='JPEG2000Metadata']/jhove:values",
                parent => "repInfo"
            },
            codestream => {
                desc => 'JHOVE JPEG2000 Codestream Metadata',
                query =>
"jhove:property[jhove:name='Codestreams']/jhove:values/jhove:property[jhove:name='Codestream']/jhove:values",
                parent => "jp2Meta"
            },
            codingStyleDefault => {
                desc => 'JHOVE JPEG2000 Coding Style Default metadata',
                query =>
"jhove:property[jhove:name='CodingStyleDefault']/jhove:values",
                parent => "codestream"
            },
            mix => {
                desc => 'JHOVE NISO/MIX image metadata',
                query =>
"jhove:property[jhove:name='NisoImageMetadata']/jhove:values/jhove:value/mix:mix",
                parent => "codestream"
            },
            uuidBox => {
                desc => 'JHOVE UUID box',
                query =>
"jhove:property[jhove:name='UUIDs']/jhove:values/jhove:property[jhove:name='UUIDBox']/jhove:values",
                parent => "jp2Meta"
            },
            xmp => {
                desc => 'XMP',
                # parent & query are set elsewhere
            }
        },

        queries => {

            # top level
            repInfo => {
                format => {
                    desc       => 'Format',
                    query      => "jhove:format",
                    remediable => 0
                },
                status => {
                    desc       => 'Status',
                    query      => "jhove:status",
                    remediable => 0
                },
                module => {
                    desc       => 'ReportingModule',
                    query      => "jhove:sigMatch/jhove:module",
                    remediable => 0
                },
                mimeType => {
                    desc       => 'MIMEtype',
                    query      => "jhove:mimeType",
                    remediable => 0
                },
            },

            # jp2Meta children
            jp2Meta => {
                brand => {
                    desc => "Brand",
                    query =>
"jhove:property[jhove:name='Brand']/jhove:values/jhove:value",
                    remediable => 0
                },
                minorVersion => {
                    desc => "MinorVersion",
                    query =>
"jhove:property[jhove:name='MinorVersion']/jhove:values/jhove:value",
                    remediable => 0
                },
                compatibility => {
                    desc => "Compatibility",
                    query =>
"jhove:property[jhove:name='Compatibility']/jhove:values/jhove:value",
                    remediable => 0
                },
                colorSpace => {
                    desc => "ColorSpecs/ColorSpec/EnumCS",
                    query =>
"jhove:property[jhove:name='ColorSpecs']/jhove:values/jhove:property[jhove:name='ColorSpec']/jhove:values/jhove:property[jhove:name='EnumCS']/jhove:values/jhove:value",
                    remediable => 0
                },
            },

            # codingStyleDefault children
            codingStyleDefault => {
                layers => {
                    desc => "NumberOfLayers",
                    query =>
"jhove:property[jhove:name='NumberOfLayers']/jhove:values/jhove:value",
                    remediable => 2
                },
                decompositionLevels => {
                    desc => "NumberDecompositionLevels",
                    query =>
"jhove:property[jhove:name='NumberDecompositionLevels']/jhove:values/jhove:value",
                    remediable => 2
                },
                transformation => {
                    desc => "Transformation",
                    query =>
"jhove:property[jhove:name='Transformation']/jhove:values/jhove:value",
                    remediable => 1
                },
            },

            # mix children
            mix => {
                compression => {
                    desc => "CompressionScheme",
                    query =>
"mix:BasicDigitalObjectInformation/mix:Compression/mix:compressionScheme",
                    remediable => 0
                },
                width => {
                    desc => "ImageWidth",
                    query =>
"mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageWidth",
                    remediable => 0
                },
                length => {
                    desc => "ImageHeight",
                    query =>
"mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageHeight",
                    remediable => 0
                },
                bitsPerSample => {
                    desc => "BitsPerSample",
                    query => "mix:ImageAssessmentMetadata/mix:ImageColorEncoding/mix:BitsPerSample/mix:bitsPerSampleValue",
                    remediable => 0
                },
                samplesPerPixel => {
                    desc => "SamplesPerPixel",
                    query => "mix:ImageAssessmentMetadata/mix:ImageColorEncoding/mix:samplesPerPixel",
                    remediable => 0
                },
            },

            # uuidBox children
            uuidBox => {
                xmp => {
                    desc => "XMP data",
                    query =>
"jhove:property[jhove:name='Data']/jhove:values/jhove:value",
                    remediable => 1
                },    # XMP text
                uuid => {
                    desc => "UUID",
                    query =>
"jhove:property[jhove:name='UUID']/jhove:values/jhove:value",
                    remediable => 1
                },    # holds identifyer accompanying an XMP field
            },

            # XMP children
            xmp => {
                width => {
                    desc       => "tiff:ImageWidth",
                    query      => "//tiff:ImageWidth",
                    remediable => 1
                },
                length => {
                    desc       => "tiff:ImageLength",
                    query      => "//tiff:ImageLength",
                    remediable => 1
                },
                bitsPerSample_grey => {
                    desc => "tiff:BitsPerSample",
                    query =>
"//tiff:BitsPerSample//*[not(*)] | //tiff:BitsPerSample[not(*)]",
                    remediable => 1
                },
                bitsPerSample_color => {
                    desc => "tiff:BitsPerSample",
                    query =>
"//tiff:BitsPerSample//*[not(*)] | //tiff:BitsPerSample[not(*)]",
                    remediable => 1
                },
                compression => {
                    desc       => "tiff:Compression",
                    query      => "//tiff:Compression",
                    remediable => 1
                },
                colorSpace => {
                    desc       => "tiff:PhotometricInterpretation",
                    query      => "//tiff:PhotometricInterpretation",
                    remediable => 1
                },
                orientation => {
                    desc       => "tiff:Orientation",
                    query      => "//tiff:Orientation",
                    remediable => 1
                },
                samplesPerPixel => {
                    desc       => "tiff:SamplesPerPixel",
                    query      => "//tiff:SamplesPerPixel",
                    remediable => 1
                },
                xRes => {
                    desc       => "tiff:XResolution",
                    query      => "//tiff:XResolution",
                    remediable => 2
                },
                yRes => {
                    desc       => "tiff:YResolution",
                    query      => "//tiff:YResolution",
                    remediable => 2
                },
                resUnit => {
                    desc       => "tiff:ResolutionUnit",
                    query      => "//tiff:ResolutionUnit",
                    remediable => 1
                },
                dateTime => {
                    desc       => "tiff:DateTime",
                    query      => "//tiff:DateTime",
                    remediable => 1
                },
                artist => {
                    desc       => "tiff:Artist",
                    query      => "//tiff:Artist",
                    remediable => 1
                },
                make => {
                    desc       => "tiff:Make",
                    query      => "//tiff:Make",
                    remediable => 1
                },
                model => {
                    desc       => "tiff:Model",
                    query      => "//tiff:Model",
                    remediable => 1
                },
                documentName => { desc => "dc:source", query => "//dc:source", remediable => 1},
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
