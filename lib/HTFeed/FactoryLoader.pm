package HTFeed::FactoryLoader;

use warnings;
use strict;
use File::Basename;
use Carp;

# common base stuff for namespace & packagetype

# hash of allowed config variables
our %allowed_config;
our @allowed_config;
our %subclass_map;
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
	my $relative_path = $module_path;
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
	    require "$relative_path/$package.pm";
	    my $subclass_identifier = ${"${caller}::${package}::identifier"};
	    croak("${caller}::${package} missing identifier")
	      unless defined $subclass_identifier;
	    $subclass_map{$caller}{$subclass_identifier} = "${caller}::${package}";
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

    my $subclass = $subclass_map{$class}{$identifier};
    croak("Unknown subclass identifier $identifier") unless $subclass;

    return bless {}, $subclass;
}

1;