package HTFeed::VolumeValidator;

use warnings;
use strict;
use Log::Log4perl qw(get_logger);
use XML::LibXML;
use HTFeed::ModuleValidator;

use base qw(HTFeed::Stage);

our $logger = get_logger(__PACKAGE__);

sub run{
	my $self = shift;
	
	my $volume $self->{volume};
	
	my @files = $volume->get_all_files;
	my $dir = $volume->get_path;
	my $volume_id = $volume->get_objid;
	
	$jhove_xml = _run_jhove($dir);
	
	# get xpc
	my $jhove_xpc;
	{
		my $jhove_parser = XML::LibXML->new();
		my $jhove_doc = $jhove_parser->parse_string($jhove_xml);
		$jhove_xpc = new XML::LibXML::XPathContext($jhove_doc);
	} 
	
	# get repInfo nodes
	my $nodelist = $jhove_xpc->findnodes("//jhove:repInfo");

	# put repInfo nodes in a usable data structure
	my %nodes = ();
	while (my $node = $nodelist->shift()){
		# get uri for this node
		my $fname = $jhove_xpc->findvalue("@uri",$node);
		# trim
		$fname =~ /(\/[0-9a-zA-Z.]*$)/;
		$fname = $1;
		
		# populate hash
		%nodes{$fname} = $node;
	}
	
	for my $file (@files){
		my $node;
		
		# get node for file
		if($node = %nodes->{file}){
			# run module validator
			my $mod_val = HTFeed::ModuleValidator->new();
			$mod_val->run();
			# check, log success
			if ($mod_val->succeeded()){
				$logger->debug("$file in $volume_id ok");
			}
			else{
				_set_error("$file bad");
			}
		}
		else _set_error("$file missing");
	}
	
	# do this last
	$self->_set_done();
}

# run jhove
sub _run_jhove{
	my $dir = shift;
	my $xml = `jhove -h XML -c /l/local/jhove-1.5/conf/jhove.conf $dir`;

	return $xml;
}


1;

__END__;
