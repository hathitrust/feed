package HTFeed::ModuleValidator::TIFF_hul;

use warnings;
use strict;

use base qw(HTFeed::ModuleValidator);

require HTFeed::QueryLib::TIFF_hul;
our $qlib = HTFeed::QueryLib::TIFF_hul->new();

=info
	TIFF-hul HTFeed validation plugin
=cut

sub _set_required_querylib{
	my $self = shift;
	$self->{qlib} = $qlib;
	return 1;
}


sub run{
	my $self = shift;
	
	# open contexts or fail
	$self->_setcontext(name => "repInfo",node => $self->{node},xpc => $self->{xpc});
		$self->_openonecontext("tiffMeta") or return;
			$self->_openonecontext("mix") or return;

	# check expected values
	$self->_validateone("repInfo","format","TIFF");
	$self->_validateone("repInfo","status","Well-Formed and valid");
	$self->_validateone("repInfo","module","TIFF-hul");
	$self->_validateone("repInfo","mimeType","image/tiff");
	$self->_validateone("mix","mime","image/tiff");
	$self->_validateone("mix","compression","4");
	$self->_validateone("mix","colorSpace","0");
	$self->_validateone("mix","orientation","1");
	$self->_validateone("mix","xRes","600");
	$self->_validateone("mix","yRes","600");
	$self->_validateone("mix","resUnit","2");
	$self->_validateone("mix","bitsPerSample","1");
	$self->_validateone("mix","samplesPerPixel","1");
	
	# check dimensions are reasonable
	my $length = $self->_findone("mix","length");
	my $width = $self->_findone("mix","width");
	unless ($length > 1 and $width > 1){
		$self->_set_error("Implausible dimensions");
	}
		
	# check/save useful info
	$self->_setdatetime( $self->_findone("mix","dateTime") );
	$self->_setartist( $self->_findone("mix","artist") );
	$self->_setdocumentname( $self->_findone("tiffMeta","documentName") );
	
	# find xmp
	my $xmp_found = 1;
	my $xmp_xml = $self->_findxmp() or $xmp_found = 0;
	
	if ($xmp_found){
		# setup xmp context
		$self->_setupXMPcontext($xmp_xml) or return 0;
		
		# check expected values
		$self->_validateone("xmp","bitsPerSample","1");
		$self->_validateone("xmp","compression","4");
		$self->_validateone("xmp","colorSpace","0");
		$self->_validateone("xmp","orientation","1");
		$self->_validateone("xmp","samplesPerPixel","1");
		$self->_validateone("xmp","xRes","600/1");
		$self->_validateone("xmp","yRes","600/1");
		$self->_validateone("xmp","resUnit","2");
		
		$self->_findonenode("xmp","make");
		$self->_findonenode("xmp","model");
		
		# check dimensions are consistant
		unless ($length == $self->_findone("xmp","length") and $width == $self->_findone("xmp","width")){
			$self->_set_error("Inconsistant dimensions");
		}
		
		# check/save useful info
		$self->_setdatetime( $self->_findone("xmp","dateTime") );
		$self->_setartist( $self->_findone("xmp","artist") );
		$self->_setdocumentname( $self->_findone("xmp","documentName") );
	}
	
	return $self->succeeded();
}

sub _findxmp{
	my $self = shift;
	my $nodelist = $self->_findnodes("tiffMeta","xmp");
	my $count = $nodelist->size();
	unless ($count) {return;}
	if ($count > 1){
		$self->_set_error("$count XMPs found zero or one expected");
		return;
	}
	my $retstring = $self->_findone("tiffMeta","xmp");
	return $retstring;
}

1;

__END__;
