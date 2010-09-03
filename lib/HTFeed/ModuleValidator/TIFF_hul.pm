package HTFeed::ModuleValidator::TIFF_hul;

use warnings;
use strict;

use base qw(HTFeed::ModuleValidator);

require HTFeed::QueryLib::TIFF_hul;
our $qlib = new HTFeed::QueryLib::TIFF_hul;

=info
	TIFF-hul HTFeed validation plugin
=cut

sub _set_required_querylib{
	my $self = shift;
	$$self{qlib} = $qlib;
}


sub run{
	my $self = shift;
	
	# open contexts or fail
	$self->_openonecontext("tiffMeta") or return 0;
		$self->_openonecontext("mix") or return 0;

	# check expected values
	$self->_validate_all_expecteds();
	
	# check dimensions are reasonable
	my $length = $self->_findone("mix_length");
	my $width = $self->_findone("mix_width");
	unless ($length > 1 and $width > 1){
		$self->_set_error("Implausible dimensions");
	}
		
	# check/save useful info
	$self->_setdatetime( $self->_findone("mix_dateTime") );
	$self->_setartist( $self->_findone("mix_artist") );
	$self->_setdocumentname( $self->_findone("meta_documentName") );
	
	# find xmp
	my $xmp_found = 1;
	my $xmp_xml = $self->_findxmp() or $xmp_found = 0;
	
	if ($xmp_found){
		# setup xmp context
		$self->_setupXMPcontext($xmp_xml) or return 0;
		
		# check expected values
		$self->_validate_expected("xmp_bitsPerSample");
		$self->_validate_expected("xmp_compression");
		$self->_validate_expected("xmp_colorSpace");
		$self->_validate_expected("xmp_orientation");
		$self->_validate_expected("xmp_samplesPerPixel");
		$self->_validate_expected("xmp_xRes");
		$self->_validate_expected("xmp_yRes");
		$self->_validate_expected("xmp_resUnit");
		
		$self->_validate_expected("xmp_make");
		$self->_validate_expected("xmp_model");
		
		# check dimensions are consistant
		unless ($length == $self->_findone("xmp_length") and $width == $self->_findone("xmp_width")){
			$self->_set_error("Inconsistant dimensions");
		}
		
		# check/save useful info
		$self->_setdatetime( $self->_findone("xmp_dateTime") );
		$self->_setartist( $self->_findone("xmp_artist") );
		$self->_setdocumentname( $self->_findone("xmp_documentName") );
	}
	
	if ($$self{fail}){
		return 0;
	}
	else{
		return 1;
	}
}

sub _findxmp{
	my $self = shift;
	my $nodelist = $self->_findnodes("xmp");
	my $count = $nodelist->size();
	return 0 unless $count;
	if ($count > 1){
		$self->_set_error("$count XMPs found zero or one expected");
		return 0;
	}
	my $retstring = $self->_findone("xmp");
	return $retstring;
}

1;

__END__;
