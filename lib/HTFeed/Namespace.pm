package HTFeed::Namespace;

use warnings;
use strict;
use Algorithm::LUHN;
use Carp;
use HTFeed::FactoryLoader;
use HTFeed::PackageType;

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
	return $self->{'packagetype'}->get($config_var);
    } else {
	return;
    }

}

# UTILITIES FOR SUBCLASSES

=item luhn_is_valid($systemid,$barcode)

Returns true if the given barcode is valid for a book according to the common
'codabar mod 10' barcode scheme and has the given system ID.

=cut

sub luhn_is_valid {
    my $self = shift;
    my $systemid = shift;
    my $barcode = shift;

    croak("Expected 4-digit systemid") if $systemid !~ /^\d{4}$/;
    return ($barcode =~ /^[34]$systemid\d{9}$/ and Algorithm::LUHN::is_valid($barcode));
    
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
