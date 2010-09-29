package HTFeed::QueryLib::JPEG2000_hul;

use warnings;
use strict;

use base qw(HTFeed::QueryLib);

=info
	JPEG2000-hul HTFeed query plugin
=cut

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
		bitsPerSample_grey  => "//tiff:BitsPerSample",
		bitsPerSample_color => "//tiff:BitsPerSample/rdf:Seq/rdf:li",
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

__END__;
