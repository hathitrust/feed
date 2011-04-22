package HTFeed::FactoryLoader;

use warnings;
use strict;
use File::Basename;
use File::Find;
use Carp;

# common base stuff for namespace & packagetype

# hash of allowed config variables
our %subclass_map;

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
        $module_path = $INC{$module_path . ".pm"} ;
        $module_path =~ s/.pm$//;

#        warn("Factory loading in $module_path\n");

        find ( { no_chdir => 1,
                wanted => sub {
                    my $file = $File::Find::name;
                    if($file =~ qr(^$module_path/([^.]*)\.pm$) and -f $file) {                        
                        my $package = $1;
                        no strict 'refs';
#                        warn("Requiring $relative_path/$package.pm in factory loader" . "\n");
                        require "$relative_path/$package.pm";
                        $package =~ s/\//::/g;
                        # determine if this package is something we should have bothered loading
                        my $is_subclass = eval "${caller}::${package}->isa(\$caller)"; 
                        if($is_subclass) {
                            my $subclass_identifier = ${"${caller}::${package}::identifier"};
                            die("${caller}::${package} missing identifier")
                                unless defined $subclass_identifier;
#                            warn("${caller}::${package} -> $subclass_identifier loaded\n");
                            $subclass_map{$caller}{$subclass_identifier} = "${caller}::${package}";

                            # run callback for when package was loaded, if it exists
                            if(eval "${caller}::${package}->can('on_factory_load')") {
                                eval "${caller}::${package}->on_factory_load()";
                                if($@) { die $@ };
                            }
                        }

                    }
            } }, $module_path );

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
