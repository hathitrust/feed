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
			waveMeta => "jhove:properties/jhove:property[jhove:name='WAVEMetadata']/jhove:values",
			aes => "jhove:property[jhove:name='AESAudioMetadata']/jhove:values/jhove:value",
		},
		queries => {
			top_repInfo => "jhove:repInfo",
			top_format => "jhove:format",
			top_status => "jhove:status",
			top_module => "jhove:sigMatch/jhove:module",
			top_mimeType => "jhove:mimeType",
			top_profile1 => "jhove:profile[1]",
			top_profile2 => "jhove:profile[2]",

			# waveMeta children
			meta_description => "jhove:property[jhove:name='Description']/jhove:values/jhove:value",
			meta_originator => "jhove:property[jhove:name='Originator']/jhove:values/jhove:value",
			meta_originationDate => "jhove:property[jhove:name='OriginationDate']/jhove:values/jhove:value",
			meta_codingHistory => "jhove:property[jhove:name='CodingHistory']/jhove:values/jhove:value",
	
			# aes children
			aes_analogDigitalFlag => "//aes:audioObject/\@ID",
			aes_format => "//aes:format",
			aes_audioDataEncoding => "//aes:audioDataEncoding",
			aes_useType => "//aesaudioObject/aes:use/\@useType",
			aes_primaryID => "//aes:primaryIdentifier",
			aes_numChannels => "//aes:numChannels",
			aes_bitDepth => "//aes:bitDepth",
			aes_sampleRate => "//aes:sampleRate",
			aes_byteOrder => "//aes:byteOrder",
			aes_sampleRate => "//aes:sampleRate",

		},
		expected =>{
                        top_format => "WAVE",
                        top_status => "Well-Formed and valid",
                        top_module => "WAVE-hul",
                        top_mimeType => "audio/x-wave",
                        top_profile1 => "PCMWAVEFORMAT",

			#waveMeta children
                        meta_originator => "University of Michigan Library",

			#aes children
			aes_numChannels => "1",

		},
		# store data on what parent to use as context for various queries
		parents => {
			# contexts
			aes => "waveMeta",
		
			# children
			meta_description => "waveMeta",
                        meta_originator => "waveMeta",
                        meta_originationDate => "waveMeta",
                        meta_codingHistory => "waveMeta",
			
			aes_analogDigitalFlag => "aes",
                        aes_format => "aes",
                        aes_audioDataEncoding => "aes",
                        aes_useType => "aes",
                        aes_primaryID => "aes",
                        aes_numChannels => "aes",
                        aes_bitDepth => "aes",
                        aes_sampleRate => "aes",
                        aes_byteOrder => "aes",
			aes_sampleRate => "aes",

		},
	};
	bless ($self, $class);
	_compile $self;
	return $self;
}

1;

__END__;
