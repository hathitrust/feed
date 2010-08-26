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
			top_format		=> "jhove:format",
			top_status		=> "jhove:status",
			top_module		=> "jhove:sigMatch/jhove:module",
			top_mimeType	=> "jhove:mimeType",
			
			# jp2Meta children
			meta_brand			=> "jhove:property[jhove:name='Brand']/jhove:values/jhove:value",
			meta_minorVersion	=> "jhove:property[jhove:name='MinorVersion']/jhove:values/jhove:value",
			meta_compatibility	=> "jhove:property[jhove:name='Compatibility']/jhove:values/jhove:value",
			meta_colorSpace		=> "jhove:property[jhove:name='ColorSpecs']/jhove:values/jhove:property[jhove:name='ColorSpec']/jhove:values/jhove:property[jhove:name='EnumCS']/jhove:values/jhove:value",
			
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
			
			# uuidBox children
			uuidBox_xmp			=> "jhove:property[jhove:name='Data']/jhove:values/jhove:value", # XMP text
			uuidBox_uuid		=> "jhove:property[jhove:name='UUID']/jhove:values/jhove:value", # holds identifyer accompanying an XMP field
			
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
			xmp_resUnit			=> "//tiff:ResolutionUnit",
			xmp_dateTime		=> "//tiff:DateTime",
			xmp_artist			=> "//tiff:Artist",
			xmp_make			=> "//tiff:Make",
			xmp_model			=> "//tiff:Model",
			xmp_documentName	=> "//dc:source",
		},
		expected =>{
			top_format		=> "JPEG 2000",
			top_status		=> "Well-Formed and valid",
			top_module		=> "JPEG2000-hul",
			top_mimeType	=> "image/jp2",
			
			meta_brand			=> "jp2 ",
			meta_minorVersion	=> "0",
			meta_compatibility	=> "jp2 ",
			
			csd_layers				=> ["1","8"],

			mix_mime			=> "image/jp2",
			mix_compression		=> "34712",
			
			xmp_compression		=> "34712",
			xmp_orientation		=> "1",
			xmp_xRes			=> ["300/1","400/1","600/1"],
			xmp_yRes			=> ["300/1","400/1","600/1"],
			xmp_resUnit			=> "2",
		},
		# store data on what parent to use as context for various queries
		parents => {
			# context queries
			codestream				=> "jp2Meta",
				codingStyleDefault		=> "codestream",
				mix						=> "codestream",
			uuidBox					=> "jp2Meta",
			
			# child queries
			meta_brand			=> "jp2Meta",
			meta_minorVersion	=> "jp2Meta",
			meta_compatibility	=> "jp2Meta",
			meta_colorSpace		=> "jp2Meta",
						
			csd_layers				=> "codingStyleDefault",
			csd_decompositionLevels	=> "codingStyleDefault",

			mix_mime			=> "mix",
			mix_compression		=> "mix",
			mix_width			=> "mix",
			mix_length			=> "mix",
			mix_bitsPerSample	=> "mix",
			mix_samplesPerPixel	=> "mix",

			uuidBox_xmp			=> "uuidBox",
			uuidBox_uuid		=> "uuidBox",
			
			# customxpc is a reserved parent name indicating to seach in a different XML::LibXML::XPathContext than other queries
			# these queries must be from the root level, no further context is supported
			xmp_width			=> "HT_customxpc",
			xmp_length			=> "HT_customxpc",
			xmp_bitsPerSample	=> "HT_customxpc",
			xmp_compression		=> "HT_customxpc",
			xmp_colorSpace		=> "HT_customxpc",
			xmp_orientation		=> "HT_customxpc",
			xmp_samplesPerPixel	=> "HT_customxpc",
			xmp_xRes			=> "HT_customxpc",
			xmp_yRes			=> "HT_customxpc",
			xmp_resUnit			=> "HT_customxpc",
			xmp_dateTime		=> "HT_customxpc",
			xmp_artist			=> "HT_customxpc",
			xmp_make			=> "HT_customxpc",
			xmp_model			=> "HT_customxpc",
			xmp_documentName	=> "HT_customxpc",
		},
	};

	bless ($self, $class);
	
	_compile $self;
	
	return $self;
}


1;

__END__;