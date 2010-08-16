
=info

UPON completion this api will be dumped into ModuleValidator

#	inherit this for some streamlined interface to XML::LibXML::XPathContext

	
	required of child:
		_set_error takes a list
		$$self{qlib} is a QueryLib object
		is a hash
=cut

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
# xp = flag to search in custom xpathcontext set in _setcustomxpc
#	default zero/false 
# 
# * is an optional field

# (qn,cnb*,xp*)
# returns nodelist object
sub _findnodes{
	
}

# (cn,cnb*,xp*)
# returns nodelist object
sub _findcontexts{
	
}

# (qn,cnb*,xp*)
# returns scalar value (generally a string)
sub _findvalue{
	
}

# (qn,cnb*,xp*)
# returns only node found or
# sets error and returns undef
sub _findonenode{
	
}

# (qn,cnb*,xp*)
# returns scalar value of only node found or
# sets error and returns 0
sub _findone{
	
}

# (cn,node)
# saves node as context node of record for cn
sub _setcontext{
	
}

# (cn,cnb*)
# saves node as context node of record for cn
# or returns 0 and sets error
sub _openonecontext{
	
}

# (text,qn,cnb*,xp*)
# "text" is the expected output of the query
# returns 1 or sets error and returns 0
sub _find_my_text_in_one_node{
	
}

# (xpc)
# takes an XML::LibXML::XPathContext object
# and saves it
sub _setcustomxpc{
	
}


=cut
my ( $self, $context, $node ) = @_;

$$self{xpc}->findnodes( $$self{qlib}->context($context), $$self{node} );
=cut