package HTFeed::ModuleValidator::JPEG2000_hul;

use warnings;
use strict;

use base qw(HTFeed::ModuleValidator);

require HTFeed::QueryLib::JPEG2000_hul;
our $qlib = HTFeed::QueryLib::JPEG2000_hul->new();

=info
	JPEG2000-hul HTFeed validation plugin
=cut

sub _set_required_querylib{
	my $self = shift;
	$self->{qlib} = $qlib;
	return 1;
}


sub run{
	my $self = shift;
	
	# open contexts
	$self->_setcontext(name => "repInfo",node => $self->{node},xpc => $self->{xpc});
		$self->_openonecontext("jp2Meta");
			$self->_openonecontext("codestream");
				$self->_openonecontext("codingStyleDefault");
				$self->_openonecontext("mix");
		
	# if we already have errors, quit now, we won't get anything else out of this without usable contexts 
	if ($self->failed){
		return;
	}

	# look for uuidbox
	{
		# find all UUID boxes
		
		my $uuidbox_nodes = $self->_findcontexts("uuidBox");
	
		# check number of uuidboxes (should equal 1)
		my $uuidbox_cnt = $uuidbox_nodes->size();
		unless ( $uuidbox_cnt == 1){
			if ($uuidbox_cnt>1){ $self->_set_error("UUIDBox not found, can't extract XMP");}
			else{ $self->_set_error("$uuidbox_cnt UUIDBox's found, XMP must be in the only UUIDBox"); }
		
			# fail
			return;
		}
	
		# check uuid
		my $uuidbox_node = $uuidbox_nodes->shift();
		$self->_setcontext(name => "uuidBox", node => $uuidbox_node);
		
		my $found_uuid = $self->_findnodes("uuidBox","uuid");
		my @reference_uuid = (-66,122,-49,-53,-105,-87,66,-24,-100,113,-103,-108,-111,-29,-81,-84);
	
		# check size
		if ($found_uuid->size() != 16) {
			$self->_set_error("UUIDBox has wrong UUID, XMP probably invalid");
		}
		else{
			my $found_entry;
			foreach my $ref_entry (@reference_uuid){
				$found_entry = $found_uuid->shift()->textContent();
				# fail as needed
				unless ($found_entry == $ref_entry){
					# found uuid that does not coorespond to an XMP
					# fail (this behavior may be changed later)
					$self->_set_error("UUIDBox has wrong UUID, XMP probably invalid");
					last;
				}
			}
		}
	}
	
	# we are in a (the) UUIDBox that holds the XMP now

	# extract the xmp
	my $xmp_xml = "";
	
	my $xml_char_nodes = $self->_findnodes("uuidBox","xmp");
	my $char_node;

	while ($char_node = $xml_char_nodes->shift()){
		$xmp_xml .= chr($char_node->textContent());
	}
	
	# setup xmp context	
	$self->_setupXMPcontext($xmp_xml);

	#########################
	# check expected values #
	#########################

	$self->_validateone("repInfo","format","JPEG 2000");
	$self->_validateone("repInfo","status","Well-Formed and valid");
	$self->_validateone("repInfo","module","JPEG2000-hul");
	$self->_validateone("repInfo","mimeType","image/jp2");
	$self->_validateone("jp2Meta","brand","jp2 ");
	$self->_validateone("jp2Meta","minorVersion","0");
	$self->_validateone("jp2Meta","compatibility","jp2 ");
	$self->_validateone("mix","mime","image/jp2");
	$self->_validateone("mix","compression","34712");
	$self->_validateone("xmp","compression","34712");
	$self->_validateone("xmp","orientation","1");
	$self->_validateone("xmp","resUnit","2");
	
	{
		# check for acceptable resolution
		my $xmp_xRes = $self->_findone("xmp","xRes");
		my $xmp_yRes = $self->_findone("xmp","yRes");
		if (!
				(	$xmp_xRes eq $xmp_yRes
					and (
						($xmp_yRes eq "300/1")
						or ($xmp_yRes eq "400/1")
						or ($xmp_yRes eq "600/1")
					)
				)
			)
		{
			$self->_set_error("invalid resolution");
		}

		my $csd_layers = $self->_findone("codingStyleDefault","layers");
		if (! (($csd_layers eq "1") or ($csd_layers eq "8")) ){
			$self->_set_error("invalid layer count");
		}

		my $dLevels = $self->_findone("codingStyleDefault","decompositionLevels");
		unless ($dLevels >= 5 and $dLevels <= 32){
			$self->_set_error("Decomposition levels = $dLevels, should be between 5 and 32 inclusive");
		}
	}
	
	{
		# check colorspace
		my $xmp_colorSpace = $self->_findone("xmp","colorSpace");
		my $xmp_samplesPerPixel = $self->_findone("xmp","samplesPerPixel");
		my $mix_samplesPerPixel = $self->_findone("mix","samplesPerPixel");
		my $meta_colorSpace = $self->_findone("jp2Meta","colorSpace");
		my $mix_bitsPerSample = $self->_findone("mix","bitsPerSample");
		my $xmp_bitsPerSample = $self->_findone("xmp","bitsPerSample");
		
		(("1" eq $xmp_colorSpace) && ("1" eq $xmp_samplesPerPixel) && ("1" eq $mix_samplesPerPixel) && ("Greyscale" eq $meta_colorSpace) && ("8" eq $mix_bitsPerSample) && ("8" eq $xmp_bitsPerSample))
		or
		(("2" eq $xmp_colorSpace) && ("3" eq $xmp_samplesPerPixel) && ("3" eq $mix_samplesPerPixel) && ("sRGB" eq $meta_colorSpace) && ("8, 8, 8" eq $mix_bitsPerSample) && ("8, 8, 8" eq $xmp_bitsPerSample))
		or
		($self->_set_error("all variables related to colorspace do not match") and return);
	}
	
	# make sure dimension records match
	{
		my $x1 = $self->_findone("mix","width");
		my $y1 = $self->_findone("mix","length");
		my $x2 = $self->_findone("xmp","width");
		my $y2 = $self->_findone("xmp","length");
		
		(($x1 > 0 && $y1 > 0 && $x2 > 0 && $y2 > 0) && ($x1 == $x2) && ($y1 == $y2)) or $self->_set_error("image dimensions not inconsistant or unreasonable");
	}
	
	# check for presence, record values
	$self->_setdatetime( $self->_findone("xmp","dateTime") );
	$self->_setartist( $self->_findone("xmp","artist") );
	$self->_setdocumentname( $self->_findone("xmp","documentName") );
	
	# check exists
	$self->_findone("xmp","make");
	$self->_findone("xmp","model");
	
	return $self->succeeded();
}

1;

__END__;
