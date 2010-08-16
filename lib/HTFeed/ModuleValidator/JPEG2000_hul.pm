package HTFeed::ModuleValidator::JPEG2000_hul;

use strict;
# just using node from libxml, not sure what really needs to be imported
# might need something for _openXMP
use XML::LibXML;

# commented out because this will likely all be in parent
# use HTFeed::QueryLib::JPEG2000_hul;

use base qw(HTFeed::ModuleValidator);
#our @ISA = qw(HTFeed::ModuleValidator);

=info
	JPEG2000-hul HTFeed validation plugin
=cut

sub _required_querylib{
	return "HTFeed::QueryLib::JPEG2000_hul";
}

sub run{
	my $self = shift;
	
	# open contexts
	$self->_openonecontext("jp2Meta");
		$self->_openonecontext("codestream","jp2Meta");
			$self->_openonecontext("codingStyleDefault","codestream");
			$self->_openonecontext("mix","codestream");
		# change to allow more uuid boxes
		$self->_openonecontext("uuidBox","jp2Meta");

		print $self->_findone("csd_layers","codingStyleDefault");
		print $self->_findone("csd_decompositionLevels","codingStyleDefault");

		print $self->_findone("mix_mime","mix");
		print $self->_findone("mix_compression","mix");
		print $self->_findone("mix_width","mix");
		print $self->_findone("mix_length","mix");
		print $self->_findone("mix_bitsPerSample","mix");
		print $self->_findone("mix_samplesPerPixel","mix");
		
		print $self->_findvalue("xmp","uuidBox");
		
	

	if ($$self{fail}){
		return 0;
	}
	else{
		print "woohoo";
		return 1;
	}
}

1;

__END__;
