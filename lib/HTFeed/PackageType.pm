package HTFeed::PackageType;


use warnings;
use strict;
use Carp;

# This has to be added before factory-loading -- automatically
# loads the volume module, stages, & module validator subclasses,
# so that they don't have to be explicitly require'd.
BEGIN {
    sub on_factory_load {
        no strict 'refs';

        my $class = shift;
        my $config = ${"${class}::config"};
        my $volclass = $config->{volume_module};
        my $stage_map = $config->{stage_map};
        my $mod_validators = $config->{module_validators};
        require_modules($volclass,values(%$stage_map),values(%$mod_validators));

    }

    sub require_modules {
        foreach my $module (@_) {
            my $modname = $module;
            next unless defined $modname and $modname ne '';
            $modname =~ s/::/\//g;
            require $modname . ".pm";
        }
    }
    our $identifier = "pkgtype";
    our $config = {
        description => "Base class for HathiTrust package types",

        # Allow gaps in numerical sequence of filename?
        allow_sequence_gaps => 0,

        # Default: no separate checksum file
        checksum_file => 0,

        # The HTFeed::ModuleValidator subclass to use for validating
        # files with the given extensions
        module_validators => {
            'jp2'  => 'HTFeed::ModuleValidator::JPEG2000_hul',
            'tif'  => 'HTFeed::ModuleValidator::TIFF_hul',
        },

        # Validation overrides
        validation => {
        },

        validation_run_stages => [
            qw(validate_file_names
              validate_filegroups_nonempty
              validate_consistency
              validate_checksums
              validate_utf8
              validate_metadata)
        ],

        premis_overrides => {
        },

        source_premis_events_extract => [],

        uncompressed_extensions => [qw(tif jp2)],

        # by default use XML schema caching. Breaks for some package types where
        # the same namespace is used for metadata that might have different 
        # schemas in different packages.
        use_schema_caching => 1,
    };
}

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
