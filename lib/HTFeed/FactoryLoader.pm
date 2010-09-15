package HTFeed::FactoryLoader;

use warnings;
use strict;
use File::Basename;
use Carp;

# common base stuff for namespace & packagetype

# hash of allowed config variables
our %allowed_config;
our @allowed_config;
our %subclasses;
@allowed_config{@allowed_config} = undef;

# Load all subclasses
sub import {

    my $class = shift;

    # If called as use HTFeed::FactoryLoader qw(load_subclasses)
    if(@_ and $_[0] eq 'load_subclasses') {

	my $caller = caller();
	# determine the subdirectory to find plugins in
	my $module_path = $caller;
	$module_path =~ s/::/\//g;
	$module_path .= '.pm';
	$module_path = $INC{$module_path};
	$module_path =~ s/.pm$//;

	my $dh;
	opendir( $dh, $module_path ) or croak("Can't readdir $module_path: $!");

	# load each apparent perl module in the subdirectory and map from
	# the identifier in each subclass to the class name
	foreach my $package (
	    map { substr( $_, 0, length($_) - 3 ) }
	    grep { /^\w+\.pm$/ && -f "$module_path/$_" } readdir $dh
	  )
	{
	    no strict 'refs';
	    require "$module_path/$package.pm";
	    my $subclass_identifier = ${"${caller}::${package}::identifier"};
	    croak("${caller}::${package} missing identifier")
	      unless defined $subclass_identifier;
	    $subclasses{$subclass_identifier} = "${caller}::${package}";

	}

	foreach my $module ( readdir $dh ) {
	    if ( $module =~ /\.pm$/ ) {
		;
		print "Requiring: $module_path/$module", "\n";
		require "$module_path/$module";
	    }
	}

	closedir($dh);
    }

}

sub get_identifier {
    no strict 'refs';
    my $self = shift;
    my $class = ref($self);
    my $subclass_identifier = ${"${class}::identifier"};
    return $subclass_identifier;
}

# must bless into subclass..
sub new {
    my $class      = shift;
    my $identifier = shift;

    $class = $subclasses{$identifier};
    croak("Unknown subclass identifier $identifier") unless $class;

    return bless {}, $class;
}

1;
