package HTFeed::ModuleValidator;

use strict;
use XML::LibXML;

use HTFeed::QueryLib;

=info
	parent class/factory for HTFeed validation plugins
	a plugin is responsible for validating Jhove output for **one Jhove module** as well as runnging any external filetype specific validation

	For general Jhove output processing see Feed::Validator
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
					qlib		=> undef,	# HTFeed::QueryLib::[appropriate child] object, holds our queries
					@_,						# override blank placeholders with proper values
					error		=> [],		# empty error array, appended by _set_error
					fail		=> 0,		# error count, incremented by _set_error, equal to $#$self{error} + 1
					contexts	=> {},		# holds nodes for contexts, orthaganal to qlib{contexts}
					customxpc	=> undef,	# a special XML::LibXML::XPathContext object for a second XML doc extracted from main doc
	};
	
	# make sure our new object is fully populated
	unless ($$object{xpc} && $$object{node} && $$object{qlib}){
		warn ("$class: too few parameters"); 
		return undef;
	}
	
	# check parameters
	unless (ref($$object{xpc}) eq "XML::LibXML::XPathContext" && ref($$object{node}) eq "XML::LibXML::Element" && ref($$object{qlib}) eq $class->_required_querylib){
		warn ("$class: invalid parameters"); 
		return undef;
	}
	
	bless ($object, $class);
	
	return $object;
}


# returns error array
sub get_errors{
	my $self = shift;
	return $self->{error};
}

# returns 0 if tests succeeded, non-0 if tests failed
sub failed{
	my $self = shift;
	return $$self{fail};
}

# put errors on error array, set fail
sub _set_error{
	my $self = shift;
	my $errors = $$self{error};
	push (@$errors, @_);
	$$self{fail}++;
}

#
# ** Methods for Running XPath Queries **
# 
# subclasses should stick to these methods to run queries when implementing validate() method
# if they aren't sufficient, extend these if possible, rather than directly running queries
#
# qn = query name (to search for)
#
# cn = context name (to search for)
#
# cnb = context name (to use as search base instead of default base of /jhove:repInfo[#])
# 
# xp = set flag to 1 to search in custom xpathcontext in _setcustomxpc
#	flag incompatible with cnb field
# 
# * is an optional field
#

# Do not actually call this method in a child, it is used in the implimentation of the other
# following helpers
# 
# general case of other methods, actual call to XML::LibXML::XPathContext->findnodes() is here
#
# (queryObj,cnb*,xp*)
sub _general_findnodes{
	my $self = shift;
	my $query = shift;
	my $xpflag = 0; # default
	my $base;

	# find $xpflag is set, act accordingly
	# TODO: this check is a little sloppy, fix it
	if ($_[0] == 1){
		$xpflag = 1;
	}
	else{
		$base = shift;
		# $base arg set, find base context in hash
		if ($base){
			$base = $$self{contexts}{$base};
		}
		# $base arg not set, get default base (top)
		else{
			$base = $$self{node};
		}
	}
	
	my $nodelist;
	# not working on special xpathcontext, act normal
	unless($xpflag){
		$nodelist = $$self{xpc}->findnodes($query,$base);
	}
	# xpflag set, work on special xpathcontext
	else{
		$nodelist = $$self{customxpc}->findnodes($query);
	}
	
	return $nodelist;
}

# (qn,cnb*,xp*)
# returns nodelist object
sub _findnodes{
	my $self = shift;
	my $query = shift;

	# get query out of qlib
	$query = $$self{qlib}->query($query);
	
	my $nodelist = $self->_general_findnodes($query,@_);

	return $nodelist;
}

# (cn,cnb*,xp*)
# returns nodelist object
sub _findcontexts{
	my $self = shift;
	my $query = shift;

	# get query out of qlib
	$query = $$self{qlib}->context($query);
	
	my $nodelist = $self->_general_findnodes($query,@_);

	return $nodelist;
}

# (qn,cnb*,xp*)
# returns only node found or
# sets error and returns undef
sub _findonenode{
	my $self = shift;
	my $qn = $_[0] or warn("_findonenode: invalid args");

	# run query
	my $nodelist = $self->_findnodes(@_);
	
	# if hit count != 1 fail
	unless ($nodelist->size() == 1){
		my $error_msg = "";
		$error_msg .= $nodelist->size();
		$error_msg .= " hits for context query: $qn exactly one expected";
		$self->_set_error($error_msg);
		return undef;
	}

	my $node = $nodelist->pop();
	return $node;
}

# (qn,cnb*,xp*)
# returns scalar value (generally a string)
sub _findvalue{
	my $self = shift;
	my $query = shift;
	my $xpflag = 0; # default
	my $base;

	# check/get query
	$query = $$self{qlib}->query($query) or warn ("_findvalue: invalid args");
	
	# find $xpflag is set, act accordingly
	# TODO: this check is a little sloppy, fix it
	if ($_[0] == 1){
		$xpflag = 1;
	}
	else{
		$base = shift;
		# $base arg set, find base context in hash
		if ($base){
			$base = $$self{contexts}{$base};
		}
		# $base arg not set, get default base (top)
		else{
			$base = $$self{node};
		}
	}
	
	my $retstring;
	# not working on special xpathcontext, act normal
	unless($xpflag){
		$retstring = $$self{xpc}->findvalue($query,$base);
	}
	# xpflag set, work on special xpathcontext
	else{
		$retstring = $$self{customxpc}->findvalue($query);
	}
	
	return $retstring;
}

# (qn,cnb*,xp*)
# returns scalar value of only node found or
# sets error and returns 0
sub _findone{
	my $self = shift;
	unless($self->_findonenode(@_)){ 
		# seterror
		# ret 0
	}
	else{
		return $self->_findvalue(@_);
	}
}

# (text,qn,cnb*,xp*)
# "text" is the expected output of the query
# returns 1 or sets error and returns 0
sub _find_my_text_in_one_node{
	my $self = shift;
	my $text = shift;
	return ($text eq $self->findone(@_));
}

# (cn,node)
# saves node as context node of record for cn
sub _setcontext{
	my $self = shift;
	my $cn = shift;
	my $node = shift;
	
	# check that $node is set, $node is correct type, $cn is a valid hash entry
	if($node && ref($node) eq "XML::LibXML::Element" && $$self{qlib}->context($cn)){
		# set
		$$self{contexts}{$cn} = $node;
	}
	else{
		# fail on wrong input;
		return 0;
	}
}

# (cn,cnb*)
# saves node as context node of record for cn
# or returns 0 and sets error
sub _openonecontext{
	my $self = shift;
	my $cn = $_[0] or warn("_openonecontext: invalid args");
	
	# run query
	my $nodelist = $self->_findcontexts(@_);
	
	# if hit count != 1 fail
	unless ($nodelist->size() == 1){
		my $error_msg = "";
		$error_msg .= $nodelist->size();
		$error_msg .= " hits for context query: $cn exactly one expected";
		$self->_set_error($error_msg);
		return 0;
	}
	my $node = $nodelist->pop();
	
	$self->_setcontext($cn,$node)
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
		warn ("couldn't parse the xmp: $@");
		return 0;
	}
	else{
		$$self{customxpc} = $xpc;
		return 1;
	}
}


1;

__END__;
