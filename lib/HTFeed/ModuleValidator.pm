package HTFeed::ModuleValidator;

use warnings;
use strict;
use Carp;
use XML::LibXML;
use Log::Log4perl qw(get_logger);

use base qw(HTFeed::XPathValidator);

#use HTFeed::ModuleValidator::ACSII_hul;
use HTFeed::ModuleValidator::JPEG2000_hul;
use HTFeed::ModuleValidator::TIFF_hul;
#use HTFeed::ModuleValidator::WAVE_hul;


# use HTFeed::QueryLib;

=info
	parent class/factory for HTFeed validation plugins
	a plugin is responsible for validating Jhove output for **one Jhove module** as well as runnging any external filetype specific validation

	For general Jhove output processing see HTFeed::Validator
=cut

=synopsis
	my $context_node = $xpc->findnodes("$repInfo/$format"."Metadata");
	my $validator = HTFeed::ModuleValidator::JPEG2000_hul->new(xpc => $xpc, node => $context_node, qlib => $querylib);
	if ($validator->validate){
		# SUCCESS code...
	}	
	else{
		my $errors = $validator->getErrors;
		# FAILURE code...
	}
=cut

# TODO: xpflag is not used remove all references to it from comments

sub new{
	my $class = shift;
	
	# make sure we are instantiating a child class, not self
	if ($class eq __PACKAGE__){
		warn __PACKAGE__ . " can only construct subclass objects";
		return undef;
	}
	
	# make empty object, populate with passed parameters
	my $object = {	xpc			=> undef,	# XML::LibXML::XPathContext object
					node 		=> undef,	# XML::LibXML::Element object, represents starting context in xpc
					id			=> undef,	# string, volume id
					filename	=> undef,	# string, filename
					@_,						# override blank placeholders with proper values
				    
					datetime		=> "",
					artist			=> "",
					documentname	=> "",
	};

	bless ($object, $class);
	
	$object->_xpathInit();
	
	# make sure our new object is fully populated
	unless ($$object{xpc} && $$object{node} && $$object{id} && $$object{filename}){
		warn ("$class: too few parameters"); 
		return undef;
	}
	
	# check parameters
	unless (ref($$object{xpc}) eq "XML::LibXML::XPathContext" && ref($$object{node}) eq "XML::LibXML::Element"){
		warn ("$class: invalid parameters"); 
		return undef;
	}
	
	return $object;
}


# validates input, checks for consistancy if already set
# sets error if needed
# returns success
sub _setdatetime{
	my $self = shift;
	my $datetime = shift;
	
	# validate
	unless ( $datetime =~ /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(\+\d\d:\d\d|)$/ ){
		$self->_set_error("Invalid timestamp format found");
		return 0;
	}
	
	# trim
	$datetime = $1;
		
	# match
	if ($$self{datetime}){
		if ($$self{datetime} eq $datetime){
			return 1;
		}
		$self->_set_error("Unmatched timestamps found");
		return 0;
	}
	# store
	$$self{datetime} = $datetime;
	return 1;
}

# validates input, checks for consistancy if already set
# sets error if needed
# returns success
sub _setartist{
	my $self = shift;
	my $artist = shift;
	
	# match
	if ($$self{artist}){
		if ($$self{artist} eq $artist){
			return 1;
		}
		$self->_set_error("Unmatched artist / file creator found");
		return 0;
	}
	# store
	$$self{artist} = $artist;
	return 1;
}

# validates input, checks for consistancy if already set
# sets error if needed
# returns success
sub _setdocumentname{
	my $self = shift;
	my $documentname = shift;

	# match
	if ($$self{documentname}){
		if ($$self{documentname} eq $documentname){
			return 1;
		}
		$self->_set_error("Unmatched document names found");
		return 0;
	}

	# validate
	my $id = $$self{id};
	my $file = $$self{filename};
	
	# deal with inconsistant use of '_' and '-'
	my $pattern = "$id/$file";
	$pattern =~ s/[-_]/\[-_\]/g;
	
	unless ($documentname =~ m|$pattern|i){
		$self->_set_error("Invalid document name found");
		return 0;
	}
	
	# store
	$$self{documentname} = $documentname;
	return 1;
}


# ($xmlstring)
# takes a string containing XML and creates a new XML::LibXML::XPathContext object with it
# return success
sub _setupXMPcontext{
	my $self = shift;
	my $xml = shift;
	
	my $xpc;
	eval{
		my $parser = XML::LibXML->new();
		my $doc = $parser->parse_string($xml);
		$xpc = new XML::LibXML::XPathContext($doc);
		
		# register XMP namespace
		my $ns_xmp = "http://ns.adobe.com/tiff/1.0/";
		$xpc->registerNs('tiff',$ns_xmp);
		# register dc namespace
		my $ns_dc = "http://purl.org/dc/elements/1.1/";
		$xpc->registerNs('dc',$ns_dc);
	};
	if($@){
		$self->_set_error("couldn't parse the xmp: $@");
		return 0;
	}
	else{
		$$self{customxpc} = $xpc;
		return 1;
	}
}

# set fail, log errors
sub _set_error{
	my $self = shift;
	$self->{fail}++;
	
	# log error w/ l4p
	for (@_){
		get_logger(ref($self))->error($_,$self->{id},$self->{filename});
	}
}

1;

__END__;
