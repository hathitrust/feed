package HTFeed::QueryLib;

use warnings;
use strict;
use XML::LibXML;

#use HTFeed::QueryLib::ACSII_hul;
#use HTFeed::QueryLib::JPEG2000_hul;
#use HTFeed::QueryLib::TIFF_hul;
#use HTFeed::QueryLib::WAVE_hul;

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
##		print "compiling $self->{contexts}->{$key}->[0]\n";
		$self->{contexts}->{$key}->[0] = new XML::LibXML::XPathExpression($self->{contexts}->{$key}->[0]);
	}
	foreach my $ikey ( keys %{$self->{queries}} ){
		foreach my $jkey ( keys %{$self->{queries}->{$ikey}} ){
##			print "compiling $self->{queries}->{$ikey}->{$jkey}\n";
			$self->{queries}->{$ikey}->{$jkey} = new XML::LibXML::XPathExpression($self->{queries}->{$ikey}->{$jkey});
		}
	}
}

# accessors
sub context{
	my $self = shift;
	my $key = shift;
	return $self->{contexts}->{$key}->[0];
}
sub context_parent{
	my $self = shift;
	my $key = shift;
	return $self->{contexts}->{$key}->[1];
}
sub query{
	my $self = shift;
	my $parent = shift;
	my $key = shift;
	return $self->{queries}->{$parent}->{$key};
}

1;

__END__;