package HTFeed::QueryLib::JPEG2000_hul;

use strict;

use base qw(HTFeed::QueryLib);

=info
	JPEG2000-hul HTFeed query plugin
=cut

sub new{	
	my $class = shift;
	
	# store all queries
	my $self = {
		contexts => {
			jp2Meta						=> "jhove:properties/jhove:property[jhove:name='JPEG2000Metadata']/jhove:values",
				codestream					=> "jhove:property[jhove:name='Codestreams']/jhove:values/jhove:property[jhove:name='Codestream']/jhove:values",
					codingStyleDefault			=> "jhove:property[jhove:name='CodingStyleDefault']/jhove:values",
					mix							=> "jhove:property[jhove:name='NisoImageMetadata']/jhove:values/jhove:value/mix:mix",
				uuidBox						=> "jhove:property[jhove:name='UUIDs']/jhove:values/jhove:property[jhove:name='UUIDBox']/jhove:values",
					# child is XMP, not treated as a context
		},
		queries => {
			# codingStyleDefault children
			csd_layers				=> "jhove:property[jhove:name='NumberOfLayers']/jhove:values/jhove:value",
			csd_decompositionLevels	=> "jhove:property[jhove:name='NumberDecompositionLevels']/jhove:values/jhove:value",
			
			# mix children
			mix_mime			=> "mix:BasicImageParameters/mix:Format/mix:MIMEType",
			mix_compression		=> "mix:BasicImageParameters/mix:Format/mix:Compression/mix:CompressionScheme",
			mix_width			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageWidth",
			mix_length			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageLength",
			mix_bitsPerSample	=> "mix:ImagingPerformanceAssessment/mix:Energetics/mix:BitsPerSample",
			mix_samplesPerPixel	=> "mix:ImagingPerformanceAssessment/mix:Energetics/mix:SamplesPerPixel",
			
			# XMP text, child of uuidBox
			xmp					=> "jhove:property[jhove:name='Data']/jhove:values/jhove:value",
			
			# XMP children
			xmp_width			=> "//tiff:ImageWidth",
			xmp_length			=> "//tiff:ImageLength",
			xmp_bitsPerSample	=> "//tiff:BitsPerSample",
			xmp_compression		=> "//tiff:Compression",
			xmp_colorSpace		=> "//tiff:PhotometricInterpretation",
			xmp_orientation		=> "//tiff:Orientation",
			xmp_samplesPerPixel	=> "//tiff:SamplesPerPixel",
			xmp_xRes			=> "//tiff:XResolution",
			xmp_yRes			=> "//tiff:YResolution",
		},
		# store data on what parent to use as context for various queries
		parents => {
			# context queries
			codestream				=> "jp2Meta",
				codingStyleDefault		=> "codestream",
				mix						=> "codestream",
			uuidBox					=> "jp2Meta",
			
			# child queries
			csd_layers				=> "codingStyleDefault",
			csd_decompositionLevels	=> "codingStyleDefault",

			mix_mime			=> "mix",
			mix_compression		=> "mix",
			mix_width			=> "mix",
			mix_length			=> "mix",
			mix_bitsPerSample	=> "mix",
			mix_samplesPerPixel	=> "mix",

			xmp					=> "uuidBox",
		}
	};

	bless ($self, $class);
	
	_compile $self;
	
	return $self;
}


1;

__END__;