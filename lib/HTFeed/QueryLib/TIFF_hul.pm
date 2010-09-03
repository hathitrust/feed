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
			tiffMeta	=> "jhove:properties/jhove:property[jhove:name='TIFFMetadata']/descendant::jhove:property[jhove:name='Entries']/jhove:values",
				mix			=> "jhove:property[jhove:name='NisoImageMetadata']/jhove:values/jhove:value/mix:mix",
		},
		queries => {
			top_format		=> "jhove:format",
			top_status		=> "jhove:status",
			top_module		=> "jhove:sigMatch/jhove:module",
			top_mimeType	=> "jhove:mimeType",

			# tiffMeta children
			meta_documentName	=> "jhove:property[jhove:name='DocmentName']/jhove:values/jhove:value",
			xmp					=> "jhove:property[jhove:name='XMP']/jhove:values/jhove:value/text()",# XMP text

			# mix children
			mix_mime			=> "mix:BasicImageParameters/mix:Format/mix:MIMEType",
			mix_compression		=> "mix:BasicImageParameters/mix:Format/mix:Compression/mix:CompressionScheme",
			mix_colorSpace		=> "mix:BasicImageParameters/mix:Format/mix:PhotometricInterpretation/mix:ColorSpace",
			mix_orientation		=> "mix:BasicImageParameters/mix:File/mix:Orientation",
			mix_artist			=> "mix:ImageCreation/mix:ImageProducer",
			mix_dateTime		=> "mix:ImageCreation/mix:DateTimeCreated",
			mix_xRes			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:XSamplingFrequency",
			mix_yRes			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:YSamplingFrequency",
			mix_resUnit			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:SamplingFrequencyUnit",
			mix_width			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageWidth",
			mix_length			=> "mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageLength",
			mix_bitsPerSample	=> "mix:ImagingPerformanceAssessment/mix:Energetics/mix:BitsPerSample",
			mix_samplesPerPixel	=> "mix:ImagingPerformanceAssessment/mix:Energetics/mix:SamplesPerPixel",

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
			top_format		=> "TIFF",
			top_status		=> "Well-Formed and valid",
			top_module		=> "TIFF-hul",
			top_mimeType	=> "image/tiff",

			# mix children
			mix_mime			=> "image/tiff",
			mix_compression		=> "4",
			mix_colorSpace		=> "0",
			mix_orientation		=> "1",
			mix_xRes			=> "600",
			mix_yRes			=> "600",
			mix_resUnit			=> "2",
			mix_bitsPerSample	=> "1",
			mix_samplesPerPixel	=> "1",

			# XMP children
			xmp_bitsPerSample	=> ["1"],
			xmp_compression		=> ["4"],
			xmp_colorSpace		=> ["0"],
			xmp_orientation		=> ["1"],
			xmp_samplesPerPixel	=> ["1"],
			xmp_xRes			=> ["600/1"],
			xmp_yRes			=> ["600/1"],
			xmp_resUnit			=> ["2"],
			xmp_make			=> ["HT_skip_check"],
			xmp_model			=> ["HT_skip_check"],
		},
		# store data on what parent to use as context for various queries
		parents => {
			# contexts
			mix					=> "tiffMeta",
			
			# children
			meta_documentName	=> "tiffMeta",
			xmp					=> "tiffMeta",
			
			mix_mime			=> "mix",
			mix_compression		=> "mix",
			mix_colorSpace		=> "mix",
			mix_orientation		=> "mix",
			mix_artist			=> "mix",
			mix_dateTime		=> "mix",
			mix_xRes			=> "mix",
			mix_yRes			=> "mix",
			mix_resUnit			=> "mix",
			mix_width			=> "mix",
			mix_length			=> "mix",
			mix_bitsPerSample	=> "mix",
			mix_samplesPerPixel	=> "mix",
			
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