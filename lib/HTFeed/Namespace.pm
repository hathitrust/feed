package HTFeed::Namespace;

use warnings;
use strict;
use Algorithm::LUHN;
use Carp;
use HTFeed::FactoryLoader 'load_subclasses';
use HTFeed::PackageType;
use HTFeed::Config qw(get_config);

use base qw(HTFeed::FactoryLoader);

sub new {
    my $class = shift;
    my $namespace_id = shift;
    my $packagetype = shift;
    my $self = $class->SUPER::new($namespace_id);
    if(defined $packagetype) {
	# Can accept either a already-constructed HTFeed::PackageType or the package type identifier.
	if(!ref($packagetype)) {
	    $packagetype = new HTFeed::PackageType($packagetype);
	}
	$self->{'packagetype'} = $packagetype;
    } else {
	croak("Missing packagetype for namespace $namespace_id"); 
    }

    return $self;
}


=item get($config)

Returns a given configuration variable. First searches the packagetype override
for a given configuration variable. If not found there, uses the namespace base
configuration, and if not there, the package type base configuration.

=cut

sub get {
    my $self = shift;
    my $config_var = shift;

    my $class = ref($self);

    no strict 'refs';

    my $packagetype_id = $self->{'packagetype'}->get_identifier();
    my $ns_pkgtype_override = ${"${class}::packagetype_overrides"}->{$packagetype_id};
    my $ns_config = ${"${class}::config"};

    if (defined $ns_pkgtype_override and defined $ns_pkgtype_override->{$config_var}) {
	return $ns_pkgtype_override->{$config_var};
    } elsif (defined $ns_config->{$config_var}) {
	return $ns_config->{$config_var};
    } elsif (defined $self->{'packagetype'}) {
	my $pkgtype_var = eval { $self->{'packagetype'}->get($config_var);
	};
	if($@) {
	    croak("Can't find namespace/packagetype configuration variable $config_var");
	} else {
	    return $pkgtype_var;
	}
    }

}

=item get_validation_overrides($module)

Collects the validation overrides from the current namespace and package type
for the given validation module (e.g.  HTFeed::ModuleValidator::JPEG2000_hul) 

=cut

sub get_validation_overrides {
    my $self = shift;
    my $module = shift;

    return $self->_get_overrides('validation');

}

# PREMIS events

=item get_event_description($eventtype)

Collects the info for a given PREMIS event type, as specified in the global configuration
and optionally overridden in package type and namespace configuration.

=cut

sub get_event_configuration {


    my $self = shift;
    my $eventtype = shift;

    no strict 'refs';

    my $eventinfo = get_config('premis_events',$eventtype);
    $self->_get_overrides('premis_overrides',$eventtype,$eventinfo);

    return $eventinfo;
}

# Gathers overrides for things like validation, PREMIS events 
# from package type, namespace, pkgtype overrides.

sub _get_overrides {
    no strict 'refs'; 

    sub _copyhash {
	my $dest = shift;
	my $src = shift;
	my $subkey = shift;

	$src = $src->{$subkey} if(defined $src and defined $subkey);

	# falls through whether original source was undef or subkey is set and
	# subkey value is undef
	return if not defined $src;
	croak("Given empty destination hash") if not defined $dest;

	while(my ($key,$val) = each(%$src)) {
	    $dest->{$key} = $val;
	}
    }

    my $self = shift;
    my $key = shift; # top-level key
    my $subkey = shift; # subkey of top-level key
    my $value = shift; # original values for field, optional
    my $class = ref($self);

    $value = {} if not defined $value;

    my $packagetype_id = $self->{'packagetype'}->get_identifier();

    my $ns_override = ${"${class}::$key"};
    _copyhash($value,$ns_override,$subkey);

    my $pkgtype_override = $self->{'packagetype'}->get($key);
    _copyhash($value,$pkgtype_override,$subkey);

    my $ns_pkgtype_override = ${"${class}::packagetype_overrides"}->{$packagetype_id};
    if(defined $ns_pkgtype_override) {
	my $ns_pkgtype_override = $ns_pkgtype_override->{$key};
	_copyhash($value,$ns_pkgtype_override,$subkey);
    }

    return $ns_pkgtype_override;
}

# UTILITIES FOR SUBCLASSES

=item luhn_is_valid($systemid,$barcode)

Returns true if the given barcode is valid for a book according to the common
'codabar mod 10' barcode scheme and has the given system ID.

=cut

sub luhn_is_valid {
    my $self = shift;
    my $itemtype_systemid = shift;
    my $barcode = shift;

    croak("Expected 5-digit item type + systemid") if $itemtype_systemid !~ /^\d{5}$/;
    return ($barcode =~ /^$itemtype_systemid\d{9}$/ and Algorithm::LUHN::is_valid($barcode));
    
}

1;
__END__

=pod

This is the superclass for all namespaces. It provides a common interface to get configuration 
variables and overrides for namespace/package type combinations.

=head1 SYNOPSIS

use HTFeed::Namespace;

$namespace = new HTFeed::Namespace('mdp','google');
$grinid = $namespace->get('grinid');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
