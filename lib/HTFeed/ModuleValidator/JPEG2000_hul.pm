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
		$self->_openonecontext("codestream");
			$self->_openonecontext("codingStyleDefault");
			$self->_openonecontext("mix");
		# TODO change to allow more uuid boxes
		$self->_openonecontext("uuidBox");

	$self->_validate_expecteds();
	
	

	if ($$self{fail}){
		return 0;
	}
	else{
#		print "woohoo\n";
		return 1;
	}
}

1;

__END__;
