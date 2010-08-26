#!/usr/bin/perl

=info
	test suite for xpath on jhove xml output
=cut


=synopsis
	# sample command
	./xpathsuite.pl -list "ls /htapps/rrotter.babel/b806977/*00.tif" [-dump dump.xml] [-xdump xdump.xml] [-ns mix:http://www.loc.gov/mix/]
	
	# change context to 1st repInfo node
	c
	/jhove:jhove/jhove:repInfo
	# get mix metadata from context of a repInfo node
	descendant::mix:mix
	# print XMP xlob
	descendant::jhove:property[jhove:name="XMP"]/jhove:values/jhove:value/text()
	# print current node?
	self::*
	# change context to root (not root node, actually root, i.e. self::* will fail here)
	c
	/
	
=cut

use strict;
use warnings;
use XML::LibXML;
use Getopt::Long;

use HTFeed::ModuleValidator;

my ($dump_file, $xdump_file, $file_list_cmd, $help, $xml_file_to_load);
my @namespaces;

my $x_mode_entered = 0;

GetOptions (	"dump=s" =>		\$dump_file,
				"xdump=s" =>	\$xdump_file,
				"list=s" =>		\$file_list_cmd,
				"load=s" =>		\$xml_file_to_load,
				"ns=s" =>		\@namespaces,	
				"help" =>		\$help					);
						
#print "Dump = $dump_file\nList = $file_list_cmd\n";
#
#for my $ns (@namespaces){
#	print join( "\t", split(/:/,$ns,2));
#	print "\n";
#}

if ($help){
	
	print "useage:\n";
	print "xpathsuite -list 'command to list infiles' [-dump dump.xml] [-xdump xdump.xml] [-ns mix:http://www.loc.gov/mix/]\n";
	print "xpathsuite -load dump.xml [-xdump xdump.xml] [-ns mix:http://www.loc.gov/mix/]\n";
	exit 0;
	
}

unless ( $file_list_cmd xor $xml_file_to_load ){ 
	print "list xor load field required, try -help flag\n"; 
	exit 0;
}

my $jhove_XML;
if ($file_list_cmd){
	# build jhove command
	my $jhove_cmd = "jhove -h XML -c /l/local/jhove-1.5/conf/jhove.conf";
	my $files = `$file_list_cmd`;
	foreach my $file ( split("\n",$files) ){
		$jhove_cmd .= " $file";
	}

	if ( $dump_file ){
		$jhove_cmd .= " | tee $dump_file";
	}
	
	# run jhove
	#print $jhove_cmd;
	$jhove_XML = `$jhove_cmd`;
}

# open XPathContext for jhove output
my $jhove_parser = XML::LibXML->new();
my $jhove_doc;
if ($jhove_XML){
	$jhove_doc = $jhove_parser->parse_string($jhove_XML);
}
else{
	$jhove_doc = $jhove_parser->parse_file($xml_file_to_load);
}
my $jhove_xpc = new XML::LibXML::XPathContext($jhove_doc);

# register ns
my $ns_jhove = "http://hul.harvard.edu/ois/xml/ns/jhove";
$jhove_xpc->registerNs('jhove',$ns_jhove);
print "registered ns, name = jhove, uri = $ns_jhove\n";

my @nsfields = undef;

for my $ns (@namespaces){
	@nsfields = split(/:/,$ns,2);
	if ($#nsfields != 1){ die("invalid ns declaration"); }
	
	$jhove_xpc->registerNs($nsfields[0],$nsfields[1]);
	print "registered ns, name = $nsfields[0], uri = $nsfields[1]\n";
}

# shell
my ($object, $xpath, $hit_cnt);
my @nodes;

print "choose menu item to enter desired mode. type help for list of menu items. ^D exits query mode, and will also exit this shell.\n";

print "top level shell> ";
while(<STDIN>){
	chomp;
	if ($_ eq ""){
		# do nothing
	}
	elsif ($_ eq "help"){
		print "q enters query mode\nc enters context change mode\nv runs validation\nx enters XMP xblob mode\nx2 enters XMP xblob mode 2 (special parsing for silly/unreasonable jhove output)\npwd roughly prints the current xpath";
	}
	elsif ($_ eq "q"){
		print "query> ";
		
		while(<STDIN>){
			$xpath = $_;

			eval{
				$object = $jhove_xpc->find($xpath);
			#	$object = $jhove_xpc->findvalue($xpath);

				print "$object\n";
			};
			if ($@) {
				print "bad query\n";
				$@ = undef;
			}
			
			print "query> ";
		}
		print "\n";
	}
	elsif ($_ eq "c"){
		print "new context> ";
		
		eval{
			$xpath = <STDIN>;
			
			@nodes = $jhove_xpc->findnodes($xpath);
			#my $nodelist = $jhove_xpc->findnodes($xpath);
			#print ref($nodelist) . "\n";
			#print $nodelist->size() . "\n";
			
			if ($#nodes + 1){
				$hit_cnt = $#nodes + 1;
				print "$hit_cnt hits, switching context to the 1st hit\n";
				$object = $nodes[0];
				$jhove_xpc->setContextNode($object);
			}
			else{
				print "Zero hits. Context not changed\n";
			}
		};
		if ($@){
			print "bad query: $@\n";
			$@ = undef;
		}
		
	}
	# this is brittle, it assumes XMP namespace, since this code has no other (present) use. will crash or enter bad state if your query is bad.
	elsif ($_ eq "x"){
		print "xlob (XML Large Object) mode (1): for XMP garbaged up with escape chars\n";
		print "Enter a query to select the xlob you want to explore. *** Query should return just the XML text ***\nExample: descendant::jhove:property[jhove:name=\"XMP\"]/jhove:values/jhove:value/text()\n";
		print "hit return without entering a query to get out safely\nxlob> ";
		$xpath = <STDIN>;
		chomp $xpath;
		if ($xpath eq ""){
			print "returning to top level shell, no changes made\n";
		}
		else{

			# get our xlob out
			my $xlob_XML = $jhove_xpc->find($xpath);
			
			# nuke the parser, make a new one with our xlob
			$jhove_parser = XML::LibXML->new();
			# make dump
			if ( $xdump_file ){
				open(XDUMP, ">$xdump_file");
				print XDUMP $xlob_XML;
				close(XDUMP);
			}
			$jhove_doc = $jhove_parser->parse_string($xlob_XML);
			$jhove_xpc = new XML::LibXML::XPathContext($jhove_doc);
			print "xlob parsed\n";
				
			registerXMP_ns();
			
		}
	}
	# see warnings on 'x' handler
	elsif ($_ eq "x2"){
		print "xlob (XML Large Object) mode (2): for XMP stuffed into decimal values\n";
		print "Enter a query to select the xlob you want to explore. *** Query should return all nodes containing the ASCII values ***\nExample: descendant::jhove:property[jhove:name=\'Data\']/jhove:values/jhove:value\n";
		print "hit return without entering a query to get out safely\nxlob> ";
		$xpath = <STDIN>;
		chomp $xpath;
		if ($xpath eq ""){
			print "returning to top level shell, no changes made\n";
		}
		else{

			# get our xlob out
			my @xml_char_nodes = $jhove_xpc->findnodes($xpath);						
			my $xlob_XML = "";
			my $char_node;
			
			while ($#xml_char_nodes + 1){
				$char_node = shift(@xml_char_nodes);
				$xlob_XML .= chr($char_node->textContent());
			}
#			print "$xlob_XML\n";
			
			# nuke the parser, make a new one with our xlob
			$jhove_parser = XML::LibXML->new();
			if ( $xdump_file ){
				open(XDUMP, ">$xdump_file");
				print XDUMP $xlob_XML;
				close(XDUMP);
			}
			$jhove_doc = $jhove_parser->parse_string($xlob_XML);
			$jhove_xpc = new XML::LibXML::XPathContext($jhove_doc);
			print "xlob parsed\n";
			
			registerXMP_ns();

		}
	}	
	# pwd
	# print path to context node
	# also prints the <name> and @attributes if present
	# attributes reported badly if number of attributes > 1, same is likely true if for more than one <name> tag
	# 
	# Namespaces NOT included in path
	#
	# output more basic for x/x2 modes
	#
	elsif ($_ eq "pwd"){
		my @tag_stack = ();
		my @attribute_stack = ();
		my @name_stack = ();
		
		my ($tag, $attribute, $name);
		
		my @query = ("name(","self::*",")");
		my $query_addition = "/parent::*";
		
		my $query_return = $jhove_xpc->findvalue( join('',@query) );
		
		# push each ancestor until we run out
		while ($query_return ne ""){
			
			push (@tag_stack, $query_return);
			$attribute =  $jhove_xpc->findvalue( join('',$query[0],$query[1],"/@*",$query[2]) );
			if ($attribute ne ""){
				$attribute .= "=\"";
				$attribute .= $jhove_xpc->findvalue( join('',$query[1],"/@*") );
				$attribute .= "\"";
			}
			push (@attribute_stack, $attribute);
			# name query will crash in xlob mode, so skip if $x_mode_entered and put junk on the stack to avoid undef errors later
			if (! $x_mode_entered){
				push (   @name_stack, $jhove_xpc->findvalue( join('',$query[1],"/jhove:name") )   );
			}
			else {
				push (@name_stack, "");
			}
			$query[1] .= $query_addition;
			#print @query;
			$query_return = $jhove_xpc->findvalue( join('',@query) );
		}
		
		# print path
		print "/";
		while ($#tag_stack + 1){
			$tag = pop(@tag_stack);
			$attribute = pop(@attribute_stack);
			$name = pop(@name_stack);
			
			print "$tag";
			# skip attributes on jhove node, they aren't interesting
			if ($attribute ne "" && $tag ne "jhove"){ print "[\@$attribute]"; }
			if ($name ne ""){ print "[name=\"$name\"]"; }
			print "/"
		}
		print "\n";
		
	}
	elsif ($_ eq "v"){
		print "enter a context for a repInfo and we'll validate it!\n> ";
		$xpath = <STDIN>;
		chomp $xpath;
		@nodes = $jhove_xpc->findnodes($xpath);
		unless ($#nodes == 0){
			if($#nodes > 0){
				print "more than one hit, be more specific\n";
			}
			else{
				print "context not found\n";
			}
		}
		else{
			#my $qlib = new HTFeed::QueryLib::JPEG2000_hul;
			my $validator = HTFeed::ModuleValidator::TIFF_hul->new(xpc=> $jhove_xpc,node => $nodes[0],id => "UOM-39015032210646",filename => "00000060.jp2");
			run $validator;
			if ($validator->failed){
				my $errors = $validator->get_errors;
				foreach my $error (@$errors){
					print "Error: $error\n";
				}
			}
			else{
				print "No errors found\n";
			}
		}	
	}
	else{
		print "invalid command, try 'help'\n";
	}

	print "top level shell> ";

}

print "\n";

sub registerXMP_ns{
	# register XMP namespace
	my $ns_xmp = "http://ns.adobe.com/tiff/1.0/";
	$jhove_xpc->registerNs('tiff',$ns_xmp);
	print "registered ns, name = tiff, uri = $ns_xmp\n";
	
	# register dc namespace
	my $ns_dc = "http://purl.org/dc/elements/1.1/";
	$jhove_xpc->registerNs('dc',$ns_dc);
	print "registered ns, name = dc, uri = $ns_dc\n";
	
	# make a note of this
	$x_mode_entered++;
}

1;

__END__;