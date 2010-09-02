package HTFeed::XPathValidator;

use warnings;
use strict;
use Carp;
use Log::Log4perl;

use base qw(HTFeed::SuccessOrFailure);

use XML::LibXML;

use constant DEBUG => 0;


sub _xpathInit{
	my $self = shift;

	$$self{contexts} = {};
	$$self{customxpc} = undef;
	$$self{fail} = 0;
	
	$self->_set_required_querylib();
	
	unless(Log::Log4perl->initialized()){
		croak "Log4Perl not initialized, cannot report errors";
	}
	
	return 1;
}

# ** methods to impliment SuccessOrFailure **

# returns 0 if tests succeeded, non-0 if tests failed
sub failed{
	my $self = shift;
	return $$self{fail};
}

# set fail, log errors
sub _set_error{
	my $self = shift;
	$$self{fail}++;
	
	# log error w/ l4p
	for (@_){
		print ref($self) . " should log here\n";
		Log::Log4perl->get_logger(ref($self))->error($_,$$self{id},$$self{filename});
	}
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
# (queryObj,qn/cn,xmp*)
sub _general_findnodes{
	my $self = shift;
	my $queryObject = shift;
	my $queryName = shift;

	my $nodelist;
	
	my $base = $$self{qlib}->parent($queryName);
	
	## verbose logging for debug
	if (DEBUG){
		print "looking for node at $queryName in $base...\n";
	}
	
	# if parent is customxpc, run search in customxpc
	if ($base eq "HT_customxpc"){
		unless ($$self{customxpc}){
			warn "Must _setcustomxpc because query $queryName is in the customxpc";
			$self->_set_error("Context missing for $queryName");
			return undef;
		}
		$nodelist = $$self{customxpc}->findnodes($queryObject);
	}
	else{
		# query has a parent (base) find base context in hash
		if ($base){
			$base = $$self{contexts}{$base};
			unless ($base){
				warn "Must _setcontext for required context for $queryName before querying";
			}
		}
		# get default base (top level)
		else{
			$base = $$self{node};
		}
		
		$nodelist = $$self{xpc}->findnodes($queryObject,$base);
	}
	
	return $nodelist;
}

# (qn,xp*)
# returns nodelist object
sub _findnodes{
	my $self = shift;
	my $query = $_[0];

	# get query out of qlib
	$query = $$self{qlib}->query($query);
	
	my $nodelist = $self->_general_findnodes($query,@_);

	return $nodelist;
}

# (cn,xp*)
# returns nodelist object
sub _findcontexts{
	my $self = shift;
	my $query = $_[0];

	# get query out of qlib
	$query = $$self{qlib}->context($query);
	
	my $nodelist = $self->_general_findnodes($query,@_);

	return $nodelist;
}

# (qn,xp*)
# returns only node found or
# sets error and returns undef
sub _findonenode{
	my $self = shift;
	my $qn = $_[0] or warn("_findonenode: invalid args");

	# run query
	my $nodelist = $self->_findnodes(@_);
	
	# detect error in _findnodes, fail
	unless ($nodelist){
		$self->_set_error("query $qn failed");
		return undef;
	}
	
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

# (qn,xp*)
# returns scalar value (generally a string)
sub _findvalue{
	my $self = shift;
	my $query = shift;

	my $retstring;
	
	# check/get query
	my $queryObj = $$self{qlib}->query($query) or warn ("_findvalue: invalid args");
	
	my $base = $$self{qlib}->parent($query);

	## verbose logging for debug
	if (DEBUG){
		print "looking for text of $query in $base...\n";
	}

	# find base is customxpc
	if ($base eq "HT_customxpc"){
		# run search on customxpc
		unless ($$self{customxpc}){
			warn "Must _setcustomxpc because query $query is in the customxpc";
			$self->_set_error("Context missing for $query");
			return "";
		}
		$retstring = $$self{customxpc}->findvalue($queryObj);
	}
	else{	
		# query has a parent (base) find base context in hash
		if ($base){
			$base = $$self{contexts}{$base};
			unless ($base){
				warn "Must _setcontext for required context for $query before querying";
			}
		}
		# get default base (top level)
		else{
			$base = $$self{node};
		}
		# run search
		$retstring = $$self{xpc}->findvalue($queryObj,$base);
	}
	
	return $retstring;
}

# (qn,xp*)
# returns scalar value of only node found or
# sets error and returns ""
sub _findone{
	my $self = shift;
	unless($self->_findonenode(@_)){ 
		return "";
	}
	else{
		return $self->_findvalue(@_);
	}
}

# ()
# validates all fields that have an expected value in %$self{qlib}->{expected}
# only validates string enrties (i.e. skips arrays)
# returns 1, or sets errors and returns 0
sub _validate_all_expecteds{
	my $self = shift;
	my $startingfailcount = $$self{fail};
	
	foreach my $key ($$self{qlib}->expectedkeys()){
		my $expectedtxt = $$self{qlib}->expected($key);
		unless (ref($expectedtxt) eq "ARRAY"){ # skip arrays, they are reserved and this method doesn't know how to use them
			my $foundtxt = $self->_findone($key);
			unless ($expectedtxt eq "HT_skip_check" or $expectedtxt eq $foundtxt){
				$self->_set_error("Text in $key is \"$foundtxt\", expected \"$expectedtxt\"");
			}
		}
	}
	
	unless ($$self{fail} == $startingfailcount){
		return 0;
	}
	
	return 1;
}

# (qn)
# validates a field based upon expected value in %$self{qlib}->{expected}
# validates string entries, 
# returns found value on success, sets error and returns undef on fail
# warning: if you are for some reason looking for a value like 0 or ""
# 	this method may not return true on success, 
sub _validate_expected{
	my $self = shift;
	my $key = shift;
	my $startingfailcount = $$self{fail};
	
	my $expected = $$self{qlib}->expected($key);
	my $foundtxt = $self->_findone($key);
	
	# query failed, error already set by _findone
	unless ($$self{fail} == $startingfailcount){
		return undef;
	}
	
	unless (ref($expected) eq "ARRAY"){
		unless ($expected eq "HT_skip_check" or $expected eq $foundtxt){
			$self->_set_error("Text in $key is \"$foundtxt\", expected \"$expected\"");
			return undef;
		}
		return $foundtxt;
	}
	else{
		my $foundit = 0;
		foreach my $expectedtxt (@$expected){
			if ($expectedtxt eq "HT_skip_check" or $expected eq $foundtxt){
				$foundit = 1;
				last;
			}
		}
		if ($foundit){
			return $foundtxt;
		}
		else{
			return undef;
		}
	}	
}

# (text,qn,xp*)
# "text" is the expected output of the query
# returns 1 or sets error and returns 0
#sub _find_my_text_in_one_node{
#	my $self = shift;
#	my $text = shift;
#	
#	my $foundtext = $self->_findone(@_);
#	if ($text eq $foundtext){
#		return 1;
#	}
#	else{
#		$self->_set_error("Text in $_[0] is \"$foundtext\", expected \"$text\"");
#		return 0;
#	}
#}

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

# (cn)
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
	
	## Debug
	#my $nv = $node->textContent;
	#print "###\n$nv\n###\n";
	
	$self->_setcontext($cn,$node)
}



1;

__END__;
