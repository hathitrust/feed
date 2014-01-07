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

        # If 0, allow only one image per page (i.e. .tif or .jp2).
        # If 1, allow (but do not require) both a .tif and .jp2 image for a given sequence number
        allow_multiple_pageimage_formats => 0,

        # Default: no separate checksum file
        checksum_file => 0,

        # initial state with which a volume should be added to the queue
        default_queue_state => 'ready',

        # The HTFeed::ModuleValidator subclass to use for validating
        # files with the given extensions
        module_validators => {
            'jp2'  => 'HTFeed::ModuleValidator::JPEG2000_hul',
            'tif'  => 'HTFeed::ModuleValidator::TIFF_hul',
        },

        # by default run no stages
        stage_map => { },

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

        # use a preingest directory
        use_preingest => 0,

        # by default use XML schema caching. Breaks for some package types where
        # the same namespace is used for metadata that might have different 
        # schemas in different packages.
        use_schema_caching => 1,

        # use default volume module
        volume_module => 'HTFeed::Volume',

        # don't migrate any events by default
        migrate_events => {},

        # use kdu_munge when remediating JPEG2000 images
        use_kdu_munge => 1,

        # do not skip any validation by default
        skip_validation => [],
        skip_validation_note => ''

    };
}

use HTFeed::FactoryLoader 'load_subclasses';
use base qw(HTFeed::FactoryLoader);

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

=head1 NAME

HTFeed::PackageType - Main class for PackageType management

=head1 SYNOPSIS

use HTFeed::PackageType;

$namespace = new HTFeed::PackageType('google');
$module_validators = $namespace->get('module_validators');

=head1 DESCRIPTION

This is the superclass for all package types. It provides an interface to get configuration 
variables and overrides for package types. Typically it would be used in conjunction with 
a namespace (see HTFeed::Namespace)

=head2 MODULES

=over 4

=item get()

Returns a given configuration variable. First searches the packagetype override
for a given configuration variable. If not found there, uses the namespace base
configuration, and if not there, the package type base configuration.

$variable = get($config);

=item require_modules()

=item on_factory_load()

=back

INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
