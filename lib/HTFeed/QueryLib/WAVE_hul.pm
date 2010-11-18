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
			waveMeta => ["jhove:properties/jhove:property[jhove:name='WAVEMetadata']/jhove:values", "repInfo"],
			aes 	=> ["jhove:property[jhove:name='AESAudioMetadata']/jhove:values/jhove:value", "waveMeta"],
		},
		queries => {
			# top level
			repInfo =>
			{
				format => "jhove:format",
				status => "jhove:status",
				module => "jhove:sigMatch/jhove:module",
				mimeType => "jhove:mimeType",
				profile1 => "jhove:profile[1]",
				profile2 => "jhove:profile[2]",
			},

			# waveMeta children
			waveMeta =>
			{
				description		=> "jhove:property[jhove:name='Description']/jhove:values/jhove:value",
				originator		=> "jhove:property[jhove:name='Originator']/jhove:values/jhove:value",
				originationDate	=> "jhove:property[jhove:name='OriginationDate']/jhove:values/jhove:value",
				codingHistory	=> "jhove:property[jhove:name='CodingHistory']/jhove:values/jhove:value",
			},

			# aes children
			aes =>
			{
				analogDigitalFlag	=> "//aes:audioObject/\@ID",
				format				=> "//aes:format",
				audioDataEncoding	=> "//aes:audioDataEncoding",
				useType				=> "//aesaudioObject/aes:use/\@useType",
				primaryID			=> "//aes:primaryIdentifier",
				numChannels			=> "//aes:numChannels",
				bitDepth			=> "//aes:bitDepth",
				sampleRate			=> "//aes:sampleRate",
				byteOrder			=> "//aes:byteOrder",
				sampleRate			=> "//aes:sampleRate",
			},
			# mets children
			mets =>
			{
			
			},
		},

	};
	bless ($self, $class);
	_compile $self;
	return $self;
}

1;

__END__;
