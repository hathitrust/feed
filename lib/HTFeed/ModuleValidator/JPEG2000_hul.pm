package HTFeed::ModuleValidator::JPEG2000_hul;

use warnings;
use strict;

use HTFeed::ModuleValidator;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::ModuleValidator);

require HTFeed::QueryLib::JPEG2000_hul;
our $qlib = HTFeed::QueryLib::JPEG2000_hul->new();

=info
	JPEG2000-hul HTFeed validation plugin
=cut

sub _set_required_querylib {
    my $self = shift;
    $self->{qlib} = $qlib;
    return 1;
}

sub _set_validators {
    my $self = shift;
    $self->{validators} = {
	'format'    => v_eq( 'repInfo', 'format', 'JPEG 2000' ),

	'status'    => v_eq( 'repInfo', 'status', 'Well-Formed and valid' ),

	'module'    => v_eq( 'repInfo', 'module', 'JPEG2000-hul' ),

	'mime_type' => v_and(
	    v_eq( 'repInfo', 'mimeType', 'image/jp2' ),
	    v_eq( 'mix',     'mime',     'image/jp2' )
	),

	'brand'         => v_eq( 'jp2Meta', 'brand',         'jp2 ' ),

	'minor_version' => v_eq( 'jp2Meta', 'minorVersion',  '0' ),

	'compatibility' => v_eq( 'jp2Meta', 'compatibility', 'jp2 ' ),

	'compression'   => v_and(
	    v_eq( 'mix', 'compression', '34712' ),    # JPEG 2000 compression
	    v_eq( 'xmp', 'compression', '34712' )
	),

	'orientation'     => v_eq( 'xmp', 'orientation', '1' ),

	'resolution_unit' => v_eq( 'xmp', 'resUnit',     '2' ),    # inches

	'resolution'      => v_and(
	    v_in( 'xmp', 'xRes', [ '300/1', '400/1', '600/1' ] ),
	    v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
	),

	'layers' => v_eq( 'codingStyleDefault', 'layers', '1' ),

	'decomposition_levels' =>
	v_between( 'codingStyleDefault', 'decompositionLevels', '5', '32' ),

	'colorspace' => sub {

	    # check colorspace
	    my $xmp_colorSpace = $self->_findone( "xmp", "colorSpace" );
	    my $xmp_samplesPerPixel =
	    $self->_findone( "xmp", "samplesPerPixel" );
	    my $mix_samplesPerPixel =
	    $self->_findone( "mix", "samplesPerPixel" );
	    my $meta_colorSpace = $self->_findone( "jp2Meta", "colorSpace" );
	    my $mix_bitsPerSample = $self->_findone( "mix", "bitsPerSample" );
	    my $xmp_bitsPerSample_grey = $self->_findvalue( "xmp", "bitsPerSample_grey" );
	    my $xmp_bitsPerSample_color = $self->_findvalue( "xmp", "bitsPerSample_color" );
	    # Greyscale: 1 sample per pixels, 8 bits per sample
	    (       ( "1" eq $xmp_colorSpace ) 		
		&& ( "1"         eq $xmp_samplesPerPixel )   
		&& ( "1"         eq $mix_samplesPerPixel )  
		&& ( "Greyscale" eq $meta_colorSpace )
		&& ( "8"         eq $mix_bitsPerSample )       
		&& ( "8"         eq $xmp_bitsPerSample_grey  or "8" eq $xmp_bitsPerSample_color) )
	    # sRGB: 3 samples per pixel, each sample 8 bits
		or (    ( "2" eq $xmp_colorSpace )
		&& ( "3"       eq $xmp_samplesPerPixel )
		&& ( "3"       eq $mix_samplesPerPixel )
		&& ( "sRGB"    eq $meta_colorSpace )
		&& ( "8,8,8"   eq $mix_bitsPerSample )
		&& ( "888"     eq $xmp_bitsPerSample_color ))
		or (
		$self->set_error(
		    "NotMatchedValue", field => 'colorspace',
		    actual => {"xmp_colorSpace" => $xmp_colorSpace,
			"xmp_samplesPerPixel" => $xmp_samplesPerPixel,
			"mix_samplesPerPixel" => $mix_samplesPerPixel,
			"jp2Meta_colorSpace" => $meta_colorSpace,
			"mix_bitsPerSample" => $mix_bitsPerSample,
			"xmp_bitsPerSample_grey" => $xmp_bitsPerSample_grey,
			"xmp_bitsPerSample_color" => $xmp_bitsPerSample_color,}
		)
		and return
	    );
    },
    'dimensions' => sub {
	my $x1 = $self->_findone( "mix", "width" );
	my $y1 = $self->_findone( "mix", "length" );
	my $x2 = $self->_findone( "xmp", "width" );
	my $y2 = $self->_findone( "xmp", "length" );
    
	( ( $x1 > 0 && $y1 > 0 && $x2 > 0 && $y2 > 0 )
	    && ( $x1 == $x2 )
	    && ( $y1 == $y2 ) )
	    or $self->set_error(
	    "NotMatchedValue", field => 'dimensions',
	    actual => {"mix_width" => $x1,
		"mix_length" => $y1,
		"xmp_width" => $x2,
		"xmp_length" => $y2});
    },
    'extract_info' => sub {

	# check for presence, record values
	$self->_setdatetime( $self->_findone( "xmp", "dateTime" ) );
	$self->_setartist( $self->_findone( "xmp", "artist" ) );
	$self->_setdocumentname( $self->_findone( "xmp", "documentName" ) );
    },
    'camera' =>
    v_and( v_exists( 'xmp', 'make' ), v_exists( 'xmp', 'model' ) )

};
}

sub run {
    my $self = shift;

    # open contexts
    $self->_setcontext(
	name => "root",
	xpc  => $self->{xpc}
    );
    $self->_openonecontext("repInfo");
    $self->_openonecontext("jp2Meta");
    $self->_openonecontext("codestream");
    $self->_openonecontext("codingStyleDefault");
    $self->_openonecontext("mix");

    # if we already have errors, quit now, we won't get anything else out of this without usable contexts
    if ( $self->failed ) {
	    return;
    }

    $self->_setupXMP;
    
    # make sure we have an xmp before we continue
    if ( $self->failed ) {
	    return;
    }

    return $self->SUPER::run();

}

sub _setupXMP {
    my $self = shift;

    # look for uuidbox, set uuidbox context
    {
        # find all UUID boxes
        my $uuidbox_nodes = $self->_findcontexts('uuidBox');

        # check that we have a uuidbox
        my $uuidbox_cnt = $uuidbox_nodes->size();
        unless ( $uuidbox_cnt > 0 ) {
            # fail
            $self->set_error('BadField',detail => 'UUIDBox not found',field => 'xmp');
            return;
        }
        
        my $uuidbox_node;
        my $xmps_found = 0; # flag if we have found it yet, we better see exactly one
        # the uuid for embedded XMP data
        my @reference_uuid = (
            -66,  122, -49,  -53,  -105, -87, 66,  -24,
            -100, 113, -103, -108, -111, -29, -81, -84
        );
        my $found_uuid;
        my $uuid_context_node_containing_xmp;
        while ($uuidbox_node = $uuidbox_nodes->shift()){
            $self->_setcontext( name => 'uuidBox', node => $uuidbox_node );
            $found_uuid = $self->_findnodes( 'uuidBox', 'uuid' );
            
            # check size
            if ( $found_uuid->size() != 16 ) {
                $self->set_error('BadValue', field => 'xmp_uuid', actual => $found_uuid, detail => 'UUID size must be 16');
                # punt, we won't be getting any further anyway
                return;
            }
            else {
                my $found_entry;
                my $is_xmp = 1;
                foreach my $ref_entry (@reference_uuid) {
                    $found_entry = $found_uuid->shift()->textContent();

                    # fail as needed
                    unless ( $found_entry == $ref_entry ) {
                        # found uuid that does not coorespond to XMP
                        $is_xmp = 0; # this isn't XMP, take the flag down
                        last;
                    }
                }
                if ($is_xmp){
                    $xmps_found++;
                    $uuid_context_node_containing_xmp = $uuidbox_node;
                }
            }
        }
        # set the uidBox context to the last uuidBox with xmp
        # if there is more than one xmp we are punting anyhow, so it doesn't matter if this is the wrong one
        $self->_setcontext( name => 'uuidBox', node => $uuid_context_node_containing_xmp );

        if ($xmps_found != 1){
            $self->set_error('BadField',detail => "$xmps_found XMPs found, expected 1",field => 'xmp');
            return;
        }
        
    }
    

    # we are in a (the) UUIDBox that holds the XMP now

    # extract the xmp
    my $xmp_xml = "";

    my $xml_char_nodes = $self->_findnodes( "uuidBox", "xmp" );
    my $char_node;

    while ( $char_node = $xml_char_nodes->shift() ) {
        $xmp_xml .= pack('c',$char_node->textContent() );
    }

    # setup xmp context
    $self->_setupXMPcontext($xmp_xml);
}

1;

__END__;
