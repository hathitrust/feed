package HTFeed::ModuleValidator;

use warnings;
use strict;
use Carp;
use XML::LibXML;
use Log::Log4perl qw(get_logger);

use base qw(HTFeed::XPathValidator);

use HTFeed::XMLNamespaces qw(register_namespaces);
use HTFeed::Config qw(get_config);

=head1 NAME

HTFeed::ModuleValidator

=head1 DESCRIPTION

	parent class/factory for HTFeed validation plugins
	a plugin is responsible for validating Jhove output for **one Jhove
	module** as well as runnging any external filetype specific validation

	For general Jhove output processing see HTFeed::Validator

=cut

=head1 SYNOPSIS

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
        xpc      => undef,    # XML::LibXML::XPathContext object
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

    my $overrides =
      $object->{volume}->get_nspkg()->get_validation_overrides($class);
    while ( my ( $k, $v ) = each(%$overrides) ) {
        $object->{validators}{$k} = $v;
    }

    return $object;
}

sub _setdatetime {
    my $self     = shift;
    my $datetime = shift;

    # validate
    unless ( defined($datetime)
        and $datetime =~
        /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(\+\d\d:\d\d|)(Z|[+-]\d{2}:\d{2})?$/ )
    {
        $self->set_error(
            "BadValue",
            field  => 'datetime',
            actual => $datetime,
            expected => 'yyyy-mm-ddThh:mm:ss[+-]hh:mm'
        );
        return 0;
    }

    # trim
    $datetime = $1;

    # match
    if ( $self->{datetime} ) {
        if ( $self->{datetime} eq $datetime ) {
            return 1;
        }
        $self->set_error(
            "NotMatchedValue",
            field    => 'datetime',
            expected => $self->{datetime},
            actual   => $datetime
        );
        return 0;
    }

    # store
    $$self{datetime} = $datetime;
    return 1;
}

sub _setartist {
    my $self   = shift;
    my $artist = shift;

    # match
    if ( $self->{artist} ) {
        if ( $self->{artist} eq $artist ) {
            return 1;
        }
        $self->set_error(
            "NotMatchedValue",
            field    => 'artist',
            expected => $self->{artist},
            actual   => $artist
        );
        return 0;
    }

    # store
    $$self{artist} = $artist;
    return 1;
}

sub _setdocumentname {
    my $self         = shift;
    my $documentname = shift;

    if( not defined $documentname or $documentname eq '') {
        $self->set_error(
            "MissingField",
            field => 'documentname'
        );
        return 0;
    }
    # match
    if ( $self->{documentname} ) {
        if ( $self->{documentname} eq $documentname ) {
            return 1;
        }
        $self->set_error(
            "NotMatchedValue",
            field    => 'documentname',
            expected => $self->{documentname},
            actual   => $documentname
        );
        return 0;
    }

    # validate
    my $id   = $$self{volume_id};
    my $file = $$self{filename};

    # deal with inconsistant use of '_' and '-'
    my $pattern = "$id/$file";
    #$pattern =~ s/[-_]/\[-_\]/g;

    # $documentname should look like "$id/$file", but "UOM_$id/$file" is allowed
    # so don't use m|^\Q$pattern\E$|i
    unless ( $documentname =~ m|\Q$pattern\E|i ) {
        $self->set_error(
            "BadValue",
            field    => 'documentname',
            expected => $pattern,
            actual   => $documentname
        );
        return 0;
    }

    # store
    $$self{documentname} = $documentname;
    return 1;
}


# setupXMPcontext($mxlstring)
# takes a string containing XML and creates a new XML::LibXML::XPathContext object with it
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
        $self->set_error( "BadField", detail => $@, field => 'xmp' );
        return 0;
    }
    else {
        $self->_setcontext( name => "xmp", xpc => $xpc );
        return 1;
    }
}

sub set_error {
    my $self  = shift;
    my $error = shift;
    $self->{fail}++;

    # log error w/ l4p
    get_logger( ref($self) )->error(
        $error,
        objid     => $self->{volume_id},
        namespace => $self->{volume}->get_namespace(),
        file      => $self->{filename},
        @_
    );
    if(get_config('stop_on_error')) {
        croak("STAGE_ERROR");
    }
    return 1;
}

sub run {

    my $self = shift;

    while ( my ( $valname, $validator ) = each( %{ $self->{validators} } ) ) {
        next unless defined $validator;
        get_logger( ref($self) )->trace(
            "Running validator $valname",
            objid     => $self->{volume_id},
            namespace => $self->{volume}->get_namespace(),
            file      => $self->{filename},
            @_
        );

        &{$validator}($self);
    }

    return $self->succeeded();
}

package HTFeed::QueryLib;

# parent class for HTFeed query plugins

# we may get some speed benefit from the precompile stage (see _compile)
# but the main reason for this class is to
# neatly organize a lot of dirty work (the queries) in one spot (the plugins)

# see HTFeed::QueryLib::JPEG2000_hul for typical subclass example

# compile all queries, this call is REQUIRED in constructor
sub _compile{
	my $self = shift;
	
	foreach my $key ( keys %{$self->{contexts}} ){
##		print "compiling $self->{contexts}->{$key}->[0]\n";
		$self->{contexts}->{$key}->[0] = XML::LibXML::XPathExpression->new($self->{contexts}->{$key}->[0]);
	}
	foreach my $ikey ( keys %{$self->{queries}} ){
		foreach my $jkey ( keys %{$self->{queries}->{$ikey}} ){
##			print "compiling $self->{queries}->{$ikey}->{$jkey}\n";
			$self->{queries}->{$ikey}->{$jkey} = XML::LibXML::XPathExpression->new($self->{queries}->{$ikey}->{$jkey});
		}
	}
	return 1;
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

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
