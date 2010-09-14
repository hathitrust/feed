package HTFeed::PackageType;

use warnings;
use strict;
use Carp;
use HTFeed::FactoryLoader 'load_subclasses';

use base qw(HTFeed::FactoryLoader);

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

    my $config = ${"${class}::config"};

    if (defined $config->{$config_var}) {
	return $config->{$config_var};
    } else {
	croak("Can't find namespace/packagetype configuration variable $config_var");
    }

}

1;
__END__

=pod

This is the superclass for all package types. It provides an interface to get configuration 
variables and overrides for package types. Typically it would be used in conjunction with 
a namespace (see HTFeed::Namespace)

=head1 SYNOPSIS

use HTFeed::PackageType;

$namespace = new HTFeed::PackageType('google');
$module_validators = $namespace->get('module_validators');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
