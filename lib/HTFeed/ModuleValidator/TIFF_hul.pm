package HTFeed::ModuleValidator::TIFF_hul;

use warnings;
use strict;

use HTFeed::ModuleValidator;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::ModuleValidator);

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
          v_and( v_gt( 'mix', 'length', '0' ), v_gt( 'mix', 'width', '0' ) ),

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
                if ( not defined $xmp_datetime or $xmp_datetime !~ /^\Q$mix_datetime\E(\+\d{2}:\d{2})?/ ) {
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

package HTFeed::QueryLib::TIFF_hul;

use warnings;
use strict;

use base qw(HTFeed::QueryLib);

=info
	TIFF-hul HTFeed query plugin
=cut

sub new{	
	my $class = shift;
	
	# store all queries
	my $self = {
		contexts => {
		    repInfo     => ["/jhove:jhove/jhove:repInfo","root"],
            # finds the TIFF IFD
			tiffMeta	=> ["jhove:properties/jhove:property[jhove:name='TIFFMetadata']//jhove:property[jhove:name='IFD']/jhove:values[jhove:property/jhove:values/jhove:value='TIFF']/jhove:property[jhove:name='Entries']/jhove:values", "repInfo"],
			mix			=> ["jhove:property[jhove:name='NisoImageMetadata']/jhove:values/jhove:value/mix:mix", "tiffMeta"],
            # xmp is a custom context set up in modulevalidator
		},
		queries => {
			# top level
			repInfo =>
			{
				format		=> "jhove:format",
				status		=> "jhove:status",
				module		=> "jhove:sigMatch/jhove:module",
				mimeType	=> "jhove:mimeType",
                errors      => 'jhove:messages/jhove:message[@severity="error"]'
			},
			
			# tiffMeta children
			tiffMeta =>
			{
				documentName	=> "jhove:property[jhove:name='DocmentName']/jhove:values/jhove:value",
				xmp					=> "jhove:property[jhove:name='XMP']/jhove:values/jhove:value/text()",# XMP text
			},
			
			# mix children
			mix =>
			{
				mime			=> "mix:BasicImageParameters/mix:Format/mix:MIMEType",
				compression		=> "mix:BasicImageParameters/mix:Format/mix:Compression/mix:CompressionScheme",
				colorSpace		=> "mix:BasicImageParameters/mix:Format/mix:PhotometricInterpretation/mix:ColorSpace",
				orientation		=> "mix:BasicImageParameters/mix:File/mix:Orientation",
				artist			=> "mix:ImageCreation/mix:ImageProducer",
				dateTime		=> "mix:ImageCreation/mix:DateTimeCreated",
				xRes			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:XSamplingFrequency",
				yRes			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:YSamplingFrequency",
				resUnit			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:SamplingFrequencyUnit",
				width			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageWidth",
				length			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageLength",
				bitsPerSample	=> "mix:ImagingPerformanceAssessment/mix:Energetics/mix:BitsPerSample",
				samplesPerPixel	=> "mix:ImagingPerformanceAssessment/mix:Energetics/mix:SamplesPerPixel",
			},

			# XMP children
			xmp =>
			{
				width			=> "//tiff:ImageWidth",
				length			=> "//tiff:ImageLength",
				bitsPerSample   => "//tiff:BitsPerSample//*[not(*)] | //tiff:BitsPerSample[not(*)]",
				compression		=> "//tiff:Compression",
				colorSpace		=> "//tiff:PhotometricInterpretation",
				orientation		=> "//tiff:Orientation",
				samplesPerPixel	=> "//tiff:SamplesPerPixel",
				xRes			=> "//tiff:XResolution",
				yRes			=> "//tiff:YResolution",
				resUnit			=> "//tiff:ResolutionUnit",
				dateTime		=> "//tiff:DateTime",
				artist			=> "//tiff:Artist",
				make			=> "//tiff:Make",
				model			=> "//tiff:Model",
				documentName	=> "//dc:source",
			},
		},
	};

	bless ($self, $class);
	
	_compile $self;
	
	return $self;
}


1;

__END__;
