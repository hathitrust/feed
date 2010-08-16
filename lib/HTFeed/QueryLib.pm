package HTFeed::QueryLib;

use strict;
use XML::LibXML;

=info
	parent class for HTFeed query plugins
	
	we may get some speed benefit from the precompile stage (see _compile)
	but the main reason for this class is to
	neatly organize a lot of dirty work (the queries) in one spot (the plugins)
	
	see HTFeed::QueryLib::JPEG2000_hul for typical subclass example
=cut

# compile all queries, this call is REQUIRED in constructor
sub _compile{
	my $self = shift;
	
	foreach my $key ( keys %{$self->{contexts}} ){
		print "compiling $$self{contexts}{$key}\n";
		$$self{contexts}{$key} = new XML::LibXML::XPathExpression($$self{contexts}{$key});
	}
	foreach my $key ( keys %{$self->{queries}} ){
		print "compiling $$self{queries}{$key}\n";
		$$self{queries}{$key} = new XML::LibXML::XPathExpression($$self{queries}{$key});
	}
}

# accessors
sub context{
	my $self = shift;
	my $key = shift;
	return $$self{contexts}{$key};
}
sub query{
	my $self = shift;
	my $key = shift;
	return $$self{queries}{$key};
}

1;

__END__;