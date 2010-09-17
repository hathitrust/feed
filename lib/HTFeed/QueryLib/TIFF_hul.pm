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
			tiffMeta	=> ["jhove:properties/jhove:property[jhove:name='TIFFMetadata']/descendant::jhove:property[jhove:name='Entries']/jhove:values", "repInfo"],
			mix			=> ["jhove:property[jhove:name='NisoImageMetadata']/jhove:values/jhove:value/mix:mix", "tiffMeta"],
		},
		queries => {
			# top level
			repInfo =>
			{
				format		=> "jhove:format",
				status		=> "jhove:status",
				module		=> "jhove:sigMatch/jhove:module",
				mimeType	=> "jhove:mimeType",
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
				bitsPerSample	=> "//tiff:BitsPerSample",
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