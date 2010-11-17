package HTFeed::ModuleValidator;

use warnings;
use strict;
use Carp;
use XML::LibXML;
use Log::Log4perl qw(get_logger);

use base qw(HTFeed::XPathValidator);

use HTFeed::ModuleValidator::JPEG2000_hul;
use HTFeed::ModuleValidator::TIFF_hul;
use HTFeed::XMLNamespaces qw(register_namespaces);

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
	my $validator = HTFeed::ModuleValidator::JPEG2000_hul->new(xpc => $xpc, qlib => $querylib);
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
        and $object->{volume}
        and $object->{filename}
        and $object->{xpc}->isa("XML::LibXML::XPathContext")
        and $object->{volume}->isa("HTFeed::Volume") );

    # get volume_id
    $object->{volume_id} = $object->{volume}->get_objid();

    # get file extension
    $object->{filename} =~ /\.([0-9a-zA-Z]+)$/;
    my $file_ext = $1;

    # get module validator list from volume, set class accordingly
    $class =
      $object->{volume}->get_nspkg()->get('module_validators')->{$file_ext}
      or croak "Don't know how to validate file extension $file_ext";

    bless( $object, $class );

    $object->_xpathInit();
    $object->_set_validators();

    my $overrides = $object->{volume}->get_nspkg()->get_validation_overrides($class);
    while(my ($k,$v) = each(%$overrides)) {
	$object->{validators}{$k} = $v;
    }

    return $object;
}

# validates input, checks for consistancy if already set
# sets error if needed
# returns success
sub _setdatetime {
    my $self     = shift;
    my $datetime = shift;

    # validate
    unless ( defined($datetime) and $datetime =~ /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(\+\d\d:\d\d|)$/ ) {
        $self->_set_error("BadValue",field => 'datetime',actual => $datetime);
        return 0;
    }

    # trim
    $datetime = $1;

    # match
    if ( $self->{datetime} ) {
        if ( $self->{datetime} eq $datetime ) {
            return 1;
        }
        $self->_set_error("NotMatchedValue",field => 'datetime',expected => $self->{datetime},actual=>$datetime);
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
    if ( $self->{artist} ) {
        if ( $self->{artist} eq $artist ) {
            return 1;
        }
        $self->_set_error("NotMatchedValue",field=>'artist',expected => $self->{artist},actual => $artist);
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
    if ( $self->{documentname} ) {
        if ( $self->{documentname} eq $documentname ) {
            return 1;
        }
        $self->_set_error("NotMatchedValue",field=>'documentname',expected => $self->{documentname}, actual=>$documentname);
        return 0;
    }

    # validate
    my $id   = $$self{volume_id};
    my $file = $$self{filename};

    # deal with inconsistant use of '_' and '-'
    my $pattern = "$id/$file";
    $pattern =~ s/[-_]/\[-_\]/g;

    unless ( $documentname =~ m|$pattern|i ) {
        $self->_set_error("BadValue",field=>'documentname',actual=>$documentname);
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

        # register namespaces
        register_namespaces($xpc);

    };
    if ($@) {
        $self->_set_error("BadField",detail=>$@,field=>'xmp');
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
    my $error = shift;
    $self->{fail}++;

    # log error w/ l4p
        get_logger( ref($self) )
          ->error( $error, volume => $self->{volume_id}, file => $self->{filename}, @_);
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
