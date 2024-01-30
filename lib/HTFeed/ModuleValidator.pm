package HTFeed::ModuleValidator;

use warnings;
use strict;

use Carp;
use Data::Dumper qw(Dumper);
use HTFeed::Config qw(get_config);
use HTFeed::XMLNamespaces qw(register_namespaces);
use Log::Log4perl qw(get_logger);
use XML::LibXML;

use base qw(HTFeed::XPathValidator);

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
	if ($validator->validate) {
		# SUCCESS code...
	} else {
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

    my $module_validators = $object->{volume}->get_nspkg()->get('module_validators');
    defined $module_validators or croak("No module_validators found for " . $object->{filename});
    my $ext_validator = $module_validators->{$file_ext};
    defined $ext_validator or croak("None of the module_validators match file_ext $file_ext");

    bless( $object, $ext_validator );
    $object->_xpathInit();
    $object->_set_validators();

    my $overrides = $object->{volume}->get_validation_overrides($ext_validator);
    while ( my ( $k, $v ) = each(%$overrides) ) {
        $object->{validators}{$k}{valid} = $v;
        $object->{validators}{$k}{desc} = $k if not defined $object->{validators}{$k}{desc};
        $object->{validators}{$k}{detail} = "Package type specific - see $ext_validator" if not defined $object->{validators}{$k}{detail};
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
            remediable => 1,
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
            field    => 'DocumentName / dc:source',
            remediable => 1,
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
            field    => 'DocumentName / dc:source',
            remediable => 1,
            expected => $self->{documentname},
            actual   => $documentname
        );
        return 0;
    }

    # validate
    my $id   = $$self{volume_id};
    my $file = $$self{filename};
    my $stripped_file = $file;

    # If the filename is like UCAL_BARCODE_00000001.tif, the dc:source can
    # match either that or the plain 00000001.tif.
    if($file =~ /^.*(\d{8}.(tif|jp2))/) {
      $stripped_file = $1;
    }

    my $pattern = "$id/$file";
    my $stripped_pattern = "$id/$stripped_file";

    # $documentname should look like "$id/$file", but "UOM_$id/$file" is allowed
    # so don't use m|^\Q$pattern\E$|i
    unless ( $documentname =~ m|\Q$pattern\E|i or $documentname =~ m|\Q$stripped_pattern\E|i) {
        $self->set_error(
            "BadValue",
            field    => 'DocumentName / dc:source',
            remediable => 1,
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
        $self->_setcontext( name => "xmp", xpc => $xpc, desc => 'XMP metadata');
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
        next unless defined $validator->{valid};
        get_logger( ref($self) )->trace(
            "Validating $validator->{desc}",
            objid     => $self->{volume_id},
            namespace => $self->{volume}->get_namespace(),
            file      => $self->{filename},
            @_
        );

        if(!&{$validator->{valid}}($self)) {
            get_logger( ref($self) ) ->warn("Validation failed",
                objid     => $self->{volume_id},
                namespace => $self->{volume}->get_namespace(),
                file      => $self->{filename},
                field     => $validator->{desc},
                detail    => $validator->{detail},
            );
        }
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
#		print "compiling $self->{contexts}->{$key}->{query}\n";
        next unless defined $self->{contexts}->{$key}->{query};
		$self->{contexts}->{$key}->{query} = XML::LibXML::XPathExpression->new($self->{contexts}->{$key}->{query});
	}
	foreach my $ikey ( keys %{$self->{queries}} ){
		foreach my $jkey ( keys %{$self->{queries}->{$ikey}} ){
#			print "compiling $self->{queries}->{$ikey}->{$jkey}->{query}\n";
            next unless defined $self->{contexts}->{$ikey}->{$jkey}->{query};
			$self->{queries}->{$ikey}->{$jkey}->{query} = XML::LibXML::XPathExpression->new($self->{queries}->{$ikey}->{$jkey}->{query});
		}
	}
	return 1;
}

# accessors
sub context{
	my $self = shift;
	my $key = shift;
	return $self->{contexts}->{$key}->{query};
}
sub context_parent{
	my $self = shift;
	my $key = shift;
	return $self->{contexts}->{$key}->{parent};
}
sub context_name {
    my $self = shift;
    my $key = shift;
    return $self->{contexts}->{$key}->{desc};
}
sub query{
	my $self = shift;
	my $parent = shift;
	my $key = shift;
	return $self->{queries}->{$parent}->{$key}->{query};
}
sub query_info {
    my $self = shift;
    my $parent = shift;
    my $key = shift;
	return $self->{queries}->{$parent}->{$key};
}

1;
