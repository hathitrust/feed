package HTFeed::ModuleValidator;

use warnings;
use strict;
use Carp;
use XML::LibXML;
use Log::Log4perl qw(get_logger);

use base qw(HTFeed::XPathValidator);

#use HTFeed::ModuleValidator::ACSII_hul;
use HTFeed::ModuleValidator::JPEG2000_hul;
use HTFeed::ModuleValidator::TIFF_hul;

#use HTFeed::ModuleValidator::WAVE_hul;

# use HTFeed::QueryLib;

=info
	parent class/factory for HTFeed validation plugins
	a plugin is responsible for validating Jhove output for **one Jhove
	module** as well as runnging any external filetype specific validation

	For general Jhove output processing see HTFeed::Validator
=cut

=synopsis
	my $context_node = $xpc->findnodes("$repInfo/$format"."Metadata");
	my $validator = HTFeed::ModuleValidator::JPEG2000_hul->new(xpc => $xpc, node => $context_node, qlib => $querylib);
	if ($validator->validate){
		# SUCCESS code...
	}	
	else{
		my $errors = $validator->getErrors;
		# FAILURE code...
	}
=cut

sub new {
    my $class = shift;

    # make empty object, populate with passed parameters
    my $object = {
        xpc => undef,    # XML::LibXML::XPathContext object
        node =>
          undef
        ,    # XML::LibXML::Element object, represents starting context in xpc
        volume   => undef,    # HTFeed::Volume
        filename => undef,    # string, filename
        @_,                   # override blank placeholders with proper values

        volume_id    => "",
        datetime     => "",
        artist       => "",
        documentname => "",    # set in _setdocumentname
    };

    if ( $class ne __PACKAGE__ ) {
        croak "use __PACKAGE__ constructor to create $class object";
    }

    # check parameters
    croak "invalid args"
      unless ( $object->{xpc}
        and $object->{node}
        and $object->{volume}
        and $object->{filename}
        and $object->{xpc}->isa("XML::LibXML::XPathContext")
        and $object->{node}->isa("XML::LibXML::Element")
        and $object->{volume}->isa("HTFeed::Volume") );

    # get volume_id
    $object->{volume_id} = $object->{volume}->get_objid();

    # get file extension
    $object->{filename} =~ /\.([0-9a-zA-Z]+)$/;
    my $file_ext = $1;

    # get module validator list from volume, set class accordingly
    $class =
      $object->{volume}->get_namespace()->get('module_validators')->{$file_ext}
      or croak "invalid file extension";

    bless( $object, $class );

    $object->_xpathInit();
    $object->_set_validators();

    return $object;
}

# validates input, checks for consistancy if already set
# sets error if needed
# returns success
sub _setdatetime {
    my $self     = shift;
    my $datetime = shift;

    # validate
    unless ( $datetime =~ /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(\+\d\d:\d\d|)$/ ) {
        $self->_set_error("Invalid timestamp format found");
        return 0;
    }

    # trim
    $datetime = $1;

    # match
    if ( $$self{datetime} ) {
        if ( $$self{datetime} eq $datetime ) {
            return 1;
        }
        $self->_set_error("Unmatched timestamps found");
        return 0;
    }

    # store
    $$self{datetime} = $datetime;
    return 1;
}

# validates input, checks for consistancy if already set
# sets error if needed
# returns success
sub _setartist {
    my $self   = shift;
    my $artist = shift;

    # match
    if ( $$self{artist} ) {
        if ( $$self{artist} eq $artist ) {
            return 1;
        }
        $self->_set_error("Unmatched artist / file creator found");
        return 0;
    }

    # store
    $$self{artist} = $artist;
    return 1;
}

# validates input, checks for consistancy if already set
# sets error if needed
# returns success
sub _setdocumentname {
    my $self         = shift;
    my $documentname = shift;

    # match
    if ( $$self{documentname} ) {
        if ( $$self{documentname} eq $documentname ) {
            return 1;
        }
        $self->_set_error("Unmatched document names found");
        return 0;
    }

    # validate
    my $id   = $$self{volume_id};
    my $file = $$self{filename};

    # deal with inconsistant use of '_' and '-'
    my $pattern = "$id/$file";
    $pattern =~ s/[-_]/\[-_\]/g;

    unless ( $documentname =~ m|$pattern|i ) {
        $self->_set_error("Invalid document name found");
        return 0;
    }

    # store
    $$self{documentname} = $documentname;
    return 1;
}

# ($xmlstring)
# takes a string containing XML and creates a new XML::LibXML::XPathContext object with it
# return success
sub _setupXMPcontext {
    my $self = shift;
    my $xml  = shift;

    my $xpc;
    eval {
        my $parser = XML::LibXML->new();
        my $doc    = $parser->parse_string($xml);
        $xpc = XML::LibXML::XPathContext->new($doc);

        # register XMP namespace
        my $ns_xmp = "http://ns.adobe.com/tiff/1.0/";
        $xpc->registerNs( 'tiff', $ns_xmp );

        # register dc namespace
        my $ns_dc = "http://purl.org/dc/elements/1.1/";
        $xpc->registerNs( 'dc', $ns_dc );
    };
    if ($@) {
        $self->_set_error("couldn't parse the xmp: $@");
        return 0;
    }
    else {
        $self->_setcontext( name => "xmp", xpc => $xpc );
        return 1;
    }
}

# set fail, log errors
sub _set_error {
    my $self = shift;
    $self->{fail}++;

    # log error w/ l4p
    for (@_) {
        get_logger( ref($self) )
          ->error( $_, $self->{volume_id}, $self->{filename} );
    }
    return 1;
}

sub run {

    my $self = shift;

    foreach my $validator ( values( %{ $self->{validators} } ) ) {
        &{$validator}($self);
    }

    return $self->succeeded();
}

1;

__END__;
