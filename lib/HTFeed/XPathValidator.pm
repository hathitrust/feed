package HTFeed::XPathValidator;

use warnings;
use strict;
use Carp;
use Log::Log4perl qw(get_logger);

use base qw(HTFeed::SuccessOrFailure);

use XML::LibXML;

my $logger = get_logger(__PACKAGE__);

sub _xpathInit{
	my $self = shift;

	$$self{contexts} = {};
	$$self{fail} = 0;
	
	$self->_set_required_querylib();
	
	unless(Log::Log4perl->initialized()){
		croak 'Log4Perl not initialized, cannot report errors';
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
# absract
sub _set_error{
	croak("This is an abstract method");
}

#
# ** Methods for Running XPath Queries **
# 
# subclasses should stick to these methods to run XPath queries
# if they aren't sufficient, extend these if possible, rather than directly running queries
#
# qn = query name (to search for)
# base = query base, the context to search in
# cn = context name (to search for)
# 

# (base, qn)
# returns nodelist object
sub _findnodes{
	my $self = shift;
	my $base = shift;
	my $qn = shift;

	# get query out of qlib
	my $query = $self->{qlib}->query($base,$qn);
	
	my $base_node = $self->{contexts}->{$base}->{node};
	my $xpc = $self->{contexts}->{$base}->{xpc};
	
	if ($xpc && $query){
		my $nodelist = $xpc->findnodes($query,$base_node);
		return $nodelist;
	}
	
	$self->_set_error("Context missing for $qn");
	return;
}

# (cn)
# returns nodelist object
sub _findcontexts{
	my $self = shift;
	my $cn = shift;
	my $base = $self->{qlib}->context_parent($cn);
	
	# get query out of qlib
	my $query = $self->{qlib}->context($cn);
	
	my $base_node = $self->{contexts}->{$base}->{node};
	my $xpc = $self->{contexts}->{$base}->{xpc};
	
	if ($xpc && $query && $base_node){
		my $nodelist = $xpc->findnodes($query,$base_node);
		return $nodelist;
	}

	return;
}

# (base, qn)
# returns only node found or
# sets error and returns undef
sub _findonenode{
	my $self = shift;
	my ($base,$qn) = @_ or croak("_findonenode: invalid args");

	# run query
	my $nodelist = $self->_findnodes(@_);
	
	# detect error in _findnodes, fail
	unless ($nodelist){
		$self->_set_error("query $qn failed");
		return;
	}
	
	# if hit count != 1 fail
	unless ($nodelist->size() == 1){
		my $error_msg = "";
		$error_msg .= $nodelist->size();
		$error_msg .= " hits for context query: $qn exactly one expected";
		$self->_set_error($error_msg);
		return;
	}

	my $node = $nodelist->pop();
	return $node;
}

# (base, qn)
# returns scalar value (generally a string)
sub _findvalue{
	my $self = shift;
	my $base = shift;
	my $query = shift;
	
	# check/get query
	my $queryObj = $self->{qlib}->query($base, $query) or croak ("_findvalue: invalid args");
	
	# verbose logging for debug
	$logger->debug("looking for text of $query in $base...");

	# get root xpc, context node
	my $context_node = $self->{contexts}->{$base}->{node};
	my $xpc = $self->{contexts}->{$base}->{xpc};

	# run query
	return $xpc->findvalue($queryObj,$context_node);
}

# (base, qn)
# returns scalar value of only node found or
# sets error and returns false
sub _findone{
	my $self = shift;
	unless($self->_findonenode(@_)){ 
		return;
	}
	else{
		return $self->_findvalue(@_);
	}
}

# (base, qn, text)
# "text" is the expected output of the query
# returns 1 or sets error and returns false
sub _validateone{
	my $self = shift;
	my $text = pop;
	
	my $foundtext = $self->_findone(@_);
	if ($text eq $foundtext){
		return 1;
	}
	else{
		$self->_set_error("Text in $_[1] is \"$foundtext\", expected \"$text\"");
		return;
	}
}

# (name => "name",node => $node,xpc => $xpc)
# xpc required unless we can get it from a parent
# node required if you don't want to always be searching from the root
#
# saves node, xpc as context of record for cn
sub _setcontext{
	my $self = shift;
	my %arg_hash = (
		name	=> undef,
		node	=> undef,
		xpc		=> undef,
		@_,
	);
	my $cn = $arg_hash{name};
	my $node = $arg_hash{node};
	my $xpc = $arg_hash{xpc};
	
	# check parameters
	if($cn && ($node || $xpc) ){
		if (! $xpc){
			# get root xpc from parent
			my $parent_name = $self->{qlib}->context_parent($cn);
			$xpc = $self->{contexts}->{$parent_name}->{xpc};
		}
		# set
		$self->{contexts}->{$cn} = {node => $node, xpc => $xpc};
		return 1;
	}
	
	# fail on wrong input;
	confess("_setcontext: invalid args");
	
}

# (cn)
# finds and saves a node as context node of record for cn
# or returns false and sets error
sub _openonecontext{
	my $self = shift;
	my ($cn) = @_ or croak("_openonecontext: invalid args");
	
	# run query
	my $nodelist = $self->_findcontexts(@_);
	
	# if hit count != 1 fail
	unless ($nodelist->size() == 1){
		my $error_msg = "";
		$error_msg .= $nodelist->size();
		$error_msg .= " hits for context query: $cn exactly one expected";
		$self->_set_error($error_msg);
		return;
	}
	my $node = $nodelist->pop();
	
	$self->_setcontext(name => $cn, node => $node);
	return 1;
}

1;

__END__;
