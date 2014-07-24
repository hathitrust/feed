package HTFeed::ModuleValidator::TIFF_hul;

use warnings;
use strict;
use HTFeed::ModuleValidator;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::ModuleValidator);

=head1 NAME

HTFeed::ModuleValidator::TIFF_hul

=head1 SYNOPSIS

	TIFF-hul HTFeed validation plugin

=cut

our $qlib = HTFeed::QueryLib::TIFF_hul->new();

sub _set_required_querylib {
    my $self = shift;
    $self->{qlib} = $qlib;
    return 1;
}

sub _set_validators {
    my $self = shift;
    $self->{validators} = {
        'format' => {
            desc  => 'Baseline TIFF format',
            valid => v_eq( 'repInfo', 'format', 'TIFF' ),
            detail =>
'This checks that JHOVE properly identified your image as being in the TIFF format. If it failed, your image may not be a TIFF image. If it can be opened with an image editor or viewer, try saving it as a TIFF image. If the image cannot be opened, it is likely severely corrupted and should be rescanned or regenerated from the source image.'
        },

        'status' => {
            desc  => 'JHOVE status',
            valid => v_eq( 'repInfo', 'status', 'Well-Formed and valid' ),
            detail =>
'This checks that the TIFF is well-formed and valid according to the TIFF specification. It may be possible to remediate the image if it is well-formed but not valid. Malformed TIFFs most likely will need to be regenerated from the source image.'
        },

        'module' => {
            desc  => 'JHOVE reporting module',
            valid => v_eq( 'repInfo', 'module', 'TIFF-hul' ),
            detail =>
'This checks that JHOVE used its TIFF plugin to extract metadata from the image. That should always be the case, so please send a bug report if you see this message.'
        },

        'mime_type' => {
            desc  => 'MIME type',
            valid => v_eq( 'repInfo', 'mimeType', 'image/tiff' ),
            detail =>
'This checks that JHOVE is reporting the images have the proper MIME type. If this check fails, the image may be in an incorrect format and likely will need to be regenerated from the source image.'
        },

        'compression' => {
            desc  => 'image compression method',
            valid => v_eq( 'mix', 'compression', 'Group 4 Fax' ),
            detail =>
'This checks that the image is compressed using CCITT Group 4 compression. If not, this can be remediated by recompressing the image with ImageMagick.'
        },    # CCITT Group 4

        'colorspace' => {
            desc  => 'color space',
            valid => v_eq( 'mix', 'colorSpace', 'WhiteIsZero' ),
            detail =>
'This checks that the image is a bitonal image and that 0 signifies white. If the color space is reported as 1 (BlackIsZero) and this is a bitonal image, then the color space can be remediated with ImageMagick. If the color space is anything else, this is likely not a bitonal image and the image should either be binarized or converted to JPEG 2000'

        },    # WhiteIsZero

        'orientation' => {
            desc  => 'image orientation',
            valid => v_eq( 'mix', 'orientation', 'normal*' ),
            detail =>
'This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.'
        },    # Horizontal/normal

        'resolution' => {
            desc  => 'resolution',
            valid => v_resolution(['600']),
            detail =>
'This checks that the image has square pixels and is scanned at a resolution of 600 pixels per inch. If the value is missing or does not reflect the actual image resolution, this can be corrected if the value is known. If the resolution information is present, correct, and not equivalent to 600 or more pixels per inch (e.g. 236 pixels per centimeter) the image will need to be rescanned or regenerated from a higher-resolution master image. Upsampling to 600 DPI bitonal images from >= 300 DPI contone images is also acceptable.'
        },

        'resolution_unit' => {
            desc  => 'resolution unit',
            valid => v_eq( 'mix', 'resUnit', 'in.' ),
            detail =>
'This checks that the resolution unit is set to 2 (inches). If not, this can be remediated by setting the resolution unit to 2 (inches) and updating the XResolution and YResolution fields as needed.'
        },

        'bits_per_sample' => {
            desc  => 'bits per sample',
            valid => v_eq( 'mix', 'bitsPerSample', '1' ),
            detail =>
'This checks that the image is bitonal. If not, the image should either be binarized or converted to JPEG 2000.'
        },

        'samples_per_pixel' => {
            desc  => 'samples per pixel',
            valid => v_eq( 'mix', 'samplesPerPixel', '1' ),
            detail =>
'This checks that the image uses only one sample per pixel. If not, it is likely a continuous tone image and should be converted to JPEG2000.'
        },

        'dimensions' => {
            desc  => 'nonzero image dimensions',
            valid => v_and(
                v_gt( 'mix', 'length', '0' ), v_gt( 'mix', 'width', '0' )
            ),
            detail =>
'This checks that the image has nonzero length and width. If not, the image is likely severely corrupted and will need to be rescanned or regenerated from the source image.'
        },

        'extract_info' => {
            desc  => "extract creation date, artist, document name",
            valid => sub {
                my $self = shift;

                # check/save useful info
                $self->_setdatetime( $self->_findone( "mix", "dateTime" ) );
                $self->_setartist( $self->_findone( "mix", "artist" ) );
                $self->_setdocumentname(
                    $self->_findone( "tiffMeta", "documentName" ) );
            },

            detail =>
'This checks that the image has creation date and scanning artist metadata as well as that it properly embeds its own source volume and filename. If not, these fields can be remediated if appropriate information is supplied.'

        },

        'xmp' => {
            desc  => 'consistency of XMP metadata',
            valid => sub {
                my $self = shift;

                # find xmp
                my $xmp_found = 1;
                my $xmp_xml = $self->_findxmp() or $xmp_found = 0;
                my $validation_ok = 1;

                if ($xmp_found) {

                    # setup xmp context
                    $self->_setupXMPcontext($xmp_xml) or return 0;

             # require XMP headers to exist and match TIFF headers if XMP exists
                    foreach my $field (
                        qw(bitsPerSample samplesPerPixel length width artist )
                      )
                    {
                        $self->_require_same( 'mix', $field, 'xmp', $field ) or $validation_ok = 0;
                    }
                    $self->_require_same( 'tiffMeta', 'documentName', 'xmp',
                        'documentName' ) or $validation_ok = 0;


                    # G4 compression
                    $self->_validateone('xmp','compression',4);
                    # colorspace - whiteiszero
                    $self->_validateone('xmp','colorSpace',0);
                    # orientation - normal
                    $self->_validateone('xmp','orientation',1);
                    # resunit
                    $self->_validateone('xmp','resUnit',2);

                    my $xmp_datetime = $self->_findone( "xmp", "dateTime" ) or $validation_ok = 0;
                    my $mix_datetime = $self->_findone( "mix", "dateTime" ) or $validation_ok = 0;

                    # xmp has timezone, mix doesn't..
                    if ( defined $xmp_datetime and defined $mix_datetime
                            and $xmp_datetime !~
                        /^\Q$mix_datetime\E(\+\d{2}:\d{2})?/ )
                    {
                        $self->set_error(
                            "NotMatchedValue",
                            field  => 'ModifyDate, XMP tiff:DateTime',
                            actual => {
                                xmp_datetime => $xmp_datetime,
                                mix_datetime => $mix_datetime
                            },
                            remediable => 1,
                        );
                        $validation_ok = 0;
                    }

                    # mix lists as just '600', XMP lists as '600/1'
                    my $res = $self->get_resolution();
                    my $xres = $self->_findone( "xmp", "xRes" );
                    my $yres = $self->_findone( "xmp", "yRes" );
                    if(defined $xres) {
                        if ( $xres =~ /^(\d+)\/1$/ ) {
                            my $xres_num = $1;
                            if($res != $xres_num) {
                                $self->set_error(
                                    "BadValue",
                                    field => "XMP tiff:XResolution",
                                    actual => $xres,
                                    expected => $res,
                                    detail => "XMP tiff:XResolution does not match IFD0:XResolution",
                                    remediable => 1);
                            }
                        }
                        else {
                            $self->set_error(
                                "BadValue",
                                field  => "XMP tiff:XResolution",
                                actual => "$xres",
                                detail => "Should be in format NNN/1",
                                remediable => 1,
                            );
                            $validation_ok = 0;
                        }

                        $self->_require_same( "xmp", "xRes", "xmp", "yRes" ) or $validation_ok = 0;
                    }

                }

                # if we made it here, it's all good?
                return $validation_ok;
            },
            detail =>
'This checks that if the TIFF image has XMP metadata that it is consistent with the baseline TIFF metadata. If not, this can normally be remediated by updating or removing the XMP metadata.'

        },

        'camera' => {
            desc  => 'scanner make and model',
            valid => sub {
                my $self = shift;
                my $ok = 1;

                # find xmp
                my $xmp_found = 1;
                my $xmp_xml = $self->_findxmp() or $xmp_found = 0;

                if ($xmp_found) {

                    # setup xmp context
                    $self->_setupXMPcontext($xmp_xml) or return 0;

                    # Optional??
                    $self->_findonenode( "xmp", "make" ) or $ok = 0;
                    $self->_findonenode( "xmp", "model" ) or $ok = 0;
                }

                return $ok;
            },

            detail =>
'This checks that the image contains information about the make and model of scanner or camera used to create it. If not, this information can be added if known.'

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

sub get_resolution {
    my $self = shift;
    my $xnum = $self->_findone("mix","xRes_numerator");
    my $xden_nodelist = $self->_findnodes("mix","xRes_denominator");
    my $xres;
    my $ynum = $self->_findone("mix","yRes_numerator");
    my $yden_nodelist = $self->_findnodes("mix","yRes_denominator");
    my $yres;

    if(defined $xden_nodelist and @$xden_nodelist) {
        $xres = $xnum / $xden_nodelist->[0]->textContent();
    } else {
        $xres = $xnum;
    }

    if(defined $yden_nodelist and @$yden_nodelist) {
        $yres = $ynum / $yden_nodelist->[0]->textContent();
    } else {
        $yres = $ynum;
    }

    if($xres != $yres)  {
        $self->set_error("NotEqualValues", $self->get_details("mix","xRes_numerator"), 
            actual => {"XSamplingFrequency" => $xres,
                "YSamplingFrequency" => $yres});
    }

    return $xres;
}

sub v_resolution_ge {
    my $allowed = shift;

    return sub {

        my $self = shift;
        my $actual_res = $self->get_resolution();

        if($actual_res >= $allowed) {
            return 1;
        }

        # did not match, fail
        $self->set_error("BadValue", $self->get_details("mix","xRes_numerator"), actual => $actual_res, expected => ">= $allowed");
    }
}

sub v_resolution {
    my $allowed = shift;

    return sub {

        my $self = shift;
        my $actual_res = $self->get_resolution();

        foreach my $expected_res (@$allowed) {
            if($actual_res == $expected_res) {
                return 1;
            }
        }

        # did not match, fail
        $self->set_error("BadValue", $self->get_details("mix","xRes_numerator"), actual => $actual_res, expected => "one of (" . join(", ",@$allowed) . ")");
    }
}

package HTFeed::QueryLib::TIFF_hul;

# TIFF-hul HTFeed query plugin

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

            # finds the TIFF IFD
            tiffMeta => {
                desc => 'JHOVE TIFF metadata',
                query =>
"jhove:properties/jhove:property[jhove:name='TIFFMetadata']//jhove:property[jhove:name='IFD']/jhove:values[jhove:property/jhove:values/jhove:value='TIFF']/jhove:property[jhove:name='Entries']/jhove:values",
                parent => "repInfo"
            },
            mix => {
                desc => 'JHOVE NISO/MIX image metadata',
                query =>
"jhove:property[jhove:name='NisoImageMetadata']/jhove:values/jhove:value/mix:mix",
                parent => "tiffMeta"
            },
            xmp => {
                desc => 'XMP metadata',
                # set up in modulevalidator
            }

        },
        queries => {

            # top level
            repInfo => {
                format => {
                    desc       => 'Format',
                    remediable => 1,
                    query      => "jhove:format"
                },
                status => {
                    desc       => 'Status',
                    remediable => 0,
                    query      => "jhove:status"
                },
                module => {
                    desc       => 'ReportingModule',
                    remediable => 0,
                    query      => "jhove:sigMatch/jhove:module"
                },
                mimeType => {
                    desc       => 'MIMEtype',
                    remediable => 0,
                    query      => "jhove:mimeType"
                },
                errors => {
                    desc       => 'Errors',
                    remediable => 2,
                    query => 'jhove:messages/jhove:message[@severity="error"]'
                }
            },

            # tiffMeta children
            tiffMeta => {
                documentName => {
                    desc       => 'DocumentName',
                    remediable => 1,
                    query =>
"jhove:property[jhove:name='DocmentName']/jhove:values/jhove:value",
                },
                xmp => {
                    desc       => 'XMP data',
                    remediable => 1,
                    query =>
"jhove:property[jhove:name='XMP']/jhove:values/jhove:value/text()"
                },    # XMP text
            },

            # mix children
            mix => {
                compression => {
                    desc       => 'CompresionScheme',
                    remediable => 1,
                    query => "mix:BasicDigitalObjectInformation/mix:Compression/mix:compressionScheme"
                },
                colorSpace => {
                    desc       => 'PhotometricInterpretation/ColorSpace',
                    remediable => 1,
                    query => "mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:PhotometricInterpretation/mix:colorSpace"
                },
                orientation => {
                    desc       => 'Orientation',
                    remediable => 1,
                    query => "mix:ImageCaptureMetadata/mix:orientation"
                },
                artist => {
                    desc       => 'ImageProducer',
                    remediable => 1,
                    query      => "mix:ImageCaptureMetadata/mix:GeneralCaptureInformation/mix:imageProducer"
                },
                dateTime => {
                    desc       => 'DateTimeCreated',
                    remediable => 1,
                    query      => "mix:ImageCaptureMetadata/mix:GeneralCaptureInformation/mix:dateTimeCreated"
                },
                xRes_numerator => {
                    desc       => 'XSamplingFrequency',
                    remediable => 2,
                    query => "mix:ImageAssessmentMetadata/mix:SpatialMetrics/mix:xSamplingFrequency/mix:numerator"
                },
                xRes_denominator => {
                    desc       => 'XSamplingFrequency',
                    remediable => 2,
                    query => "mix:ImageAssessmentMetadata/mix:SpatialMetrics/mix:xSamplingFrequency/mix:denominator"
                },
                yRes_numerator => {
                    desc       => 'YSamplingFrequency',
                    remediable => 2,
                    query => "mix:ImageAssessmentMetadata/mix:SpatialMetrics/mix:ySamplingFrequency/mix:numerator"
                },
                yRes_denominator => {
                    desc       => 'YSamplingFrequency',
                    remediable => 2,
                    query => "mix:ImageAssessmentMetadata/mix:SpatialMetrics/mix:ySamplingFrequency/mix:denominator"
                },
                resUnit => {
                    desc       => 'SamplingFrequencyUnit',
                    remediable => 1,
                    query => "mix:ImageAssessmentMetadata/mix:SpatialMetrics/mix:samplingFrequencyUnit"
                },
                width => {
                    desc       => 'ImageWidth',
                    remediable => 0, 
                    query => "mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageWidth",
                },
                length => {
                    desc       => 'ImageHeight',
                    remediable => 0, 
                    query => "mix:BasicImageInformation/mix:BasicImageCharacteristics/mix:imageHeight",
                },
                bitsPerSample => {
                    desc       => 'BitsPerSample',
                    remediable => 0,
                    query => "mix:ImageAssessmentMetadata/mix:ImageColorEncoding/mix:BitsPerSample/mix:bitsPerSampleValue"
                },
                samplesPerPixel => {
                    desc       => 'SamplesPerPixel',
                    remediable => 0,
                    query => "mix:ImageAssessmentMetadata/mix:ImageColorEncoding/mix:samplesPerPixel"
                },
            },

            # XMP children
            xmp => {
                width => {
                    desc       => 'tiff:ImageWidth',
                    remediable => 1,
                    query      => "//tiff:ImageWidth"
                },
                length => {
                    desc       => 'tiff:ImageLength',
                    remediable => 1,
                    query      => "//tiff:ImageLength"
                },
                bitsPerSample => {
                    desc       => 'tiff:BitsPersample',
                    remediable => 1,
                    query =>
"//tiff:BitsPerSample//*[not(*)] | //tiff:BitsPerSample[not(*)]"
                },
                compression => {
                    desc       => 'tiff:Compression',
                    remediable => 1,
                    query      => "//tiff:Compression"
                },
                colorSpace => {
                    desc       => 'tiff:PhotometricInterpretation',
                    remediable => 1,
                    query      => "//tiff:PhotometricInterpretation"
                },
                orientation => {
                    desc       => 'tiff:Orientation',
                    remediable => 1,
                    query      => "//tiff:Orientation"
                },
                samplesPerPixel => {
                    desc       => 'tiff:SamplesPerPixel',
                    remediable => 1,
                    query      => "//tiff:SamplesPerPixel"
                },
                xRes => {
                    desc       => 'tiff:XResolution',
                    remediable => 2,
                    query      => "//tiff:XResolution"
                },
                yRes => {
                    desc       => 'tiff:YResolution',
                    remediable => 2,
                    query      => "//tiff:YResolution"
                },
                resUnit => {
                    desc       => 'tiff:ResolutionUnit',
                    remediable => 1,
                    query      => "//tiff:ResolutionUnit"
                },
                dateTime => {
                    desc       => 'tiff:DateTime',
                    remediable => 1,
                    query      => "//tiff:DateTime"
                },
                artist => {
                    desc       => 'tiff:Artist',
                    remediable => 1,
                    query      => "//tiff:Artist"
                },
                make => { 
                    desc => 'tiff:Make', 
                    remediable => 1, 
                    query => "//tiff:Make" 
                },
                model => {
                    desc       => 'tiff:Model',
                    remediable => 1,
                    query      => "//tiff:Model"
                },
                documentName => {
                    desc       => 'dc:source',
                    remediable => 1,
                    query      => "//dc:source"
                },
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
