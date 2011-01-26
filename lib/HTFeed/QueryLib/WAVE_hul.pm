package HTFeed::QueryLib::WAVE_hul;

use strict;
use base qw(HTFeed::QueryLib);

=info
	WAVE-hul HTFeed query plugin
=cut

sub new{	
	my $class = shift;
	
	# store all queries
	my $self = {
		contexts => {
			repInfo 	=> ["/jhove:jhove/jhove:repInfo", "root"],
			waveMeta 	=> ["jhove:properties/jhove:property[jhove:name='WAVEMetadata']/jhove:values", "repInfo"],
			aes 		=> ["jhove:property[jhove:name='AESAudioMetadata']/jhove:values/jhove:value/aes:audioObject", "waveMeta"],
		},
		
		queries => {
			# top level
			repInfo =>
			{
				format => "jhove:format",
				status => "jhove:status",
				module => "jhove:sigMatch/jhove:module",
				mimeType => "jhove:mimeType",
				profile1 => "jhove:profiles/jhove:profile[1]",
				profile2 => "jhove:profiles/jhove:profile[2]",
			},

			# waveMeta children
			waveMeta =>
			{
				description		=> "jhove:property/jhove:values/jhove:property[jhove:name='Description']",
				originator		=> "jhove:property/jhove:values/jhove:property[jhove:name='Originator']/jhove:values/jhove:value",
				originationDate	=> "jhove:property/jhove:values/jhove:property[jhove:name='OriginationDate']",
				codingHistory	=> "jhove:property/jhove:values/jhove:property[jhove:name='CodingHistory']",
			},

			# aes children
			aes =>
			{
				analogDigitalFlag	=> "\@analogDigitalFlag",
				format				=> "aes:format",
				audioDataEncoding	=> "aes:audioDataEncoding",
				useType				=> "aes:use/\@useType",
				primaryID			=> "aes:primaryIdentifier",
				numChannels			=> "aes:face/aes:region/aes:numChannels",
				bitDepth			=> "aes:formatList/aes:formatRegion/aes:bitDepth",
				sampleRate			=> "aes:formatList/aes:formatRegion/aes:sampleRate",
				byteOrder			=> "aes:byteOrder",
			},

		},

	};
	bless ($self, $class);
	_compile $self;
	return $self;
}

1;

__END__;
