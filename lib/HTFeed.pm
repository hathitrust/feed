package HTFeed;

use warnings;
use strict;
no strict 'refs';

use version 0.77; use HTFeed::Version qw(:no_getopt); our $VERSION = version->declare(HTFeed::Version::get_vstring());

my $loaded_namespaces = 0;
my $loaded_pkgtypes = 0;

use HTFeed::Volume;
use HTFeed::Config qw(get_config);
use HTFeed::Volume;
use HTFeed::PackageType;
use HTFeed::Namespace;

use base qw( Exporter );
our @EXPORT_OK = qw( tagmatch search_ns_by_tags );

sub find_subclasses {
    my $class = shift;

    return grep { eval "$_->isa('$class') and '$_' ne '$class'" }
        (map { s/\//::/g; s/\.pm//g; $_} 
            ( grep { /.pm$/ } (keys %INC)));
}

sub namespace_ids {
    load_namespaces();
    return map {${$_ . "::identifier"}} (sort(find_subclasses("HTFeed::Namespace")));
}

sub pkgtype_ids {
    load_pkgtypes();
    return map {${$_ . "::identifier"}} (sort(find_subclasses("HTFeed::PackageType")));
}

sub id_desc_info {
    my $class = shift;
    my $key = ${$class . "::identifier"};
    my $desc = ${$class . "::config"}->{description};
    return "$class - $key - $desc";
}

sub nspkg {
    load_namespaces();
    return map {$_ => {id_desc_info($_)}} find_subclasses("HTFeed::Namespace");
}

sub load_namespaces {
    if(!$loaded_namespaces) {
        HTFeed::Namespace->load_all_subclasses();
        $loaded_namespaces = 1;
    }
}

sub load_pkgtypes {
    if(!$loaded_pkgtypes) {
        HTFeed::PackageType->load_all_subclasses();
        $loaded_pkgtypes = 1;
    }
}


=item pkg_by_ns

pkg_by_ns()

return hashref of namespaces mapped to their packagetypes

=cut
my $namespace_to_packagetype_hash;
sub pkg_by_ns {
	return $namespace_to_packagetype_hash if(defined $namespace_to_packagetype_hash);

    load_namespaces();
    load_pkgtypes();
    my %hsh = map {${$_ . "::identifier"}=>${$_ . "::config"}->{packagetypes}} (sort(find_subclasses("HTFeed::Namespace")));

	$namespace_to_packagetype_hash = \%hsh;
    return $namespace_to_packagetype_hash;
}

=item ns_by_pkg

ns_by_pkg()

return hashref of packagetypes mapped to their namespaces

=cut
my $packagetype_to_namespace_hash;
sub ns_by_pkg {
	return $packagetype_to_namespace_hash if(defined $packagetype_to_namespace_hash);

    load_namespaces();
    load_pkgtypes();
    my $pkg_by_ns = pkg_by_ns();
    my %ns_by_pkg;
    foreach my $ns (keys %{$pkg_by_ns}){
        foreach my $pkg (@{$pkg_by_ns->{$ns}}){
            $ns_by_pkg{$pkg} = []
                unless (defined $ns_by_pkg{$pkg});
            push @{$ns_by_pkg{$pkg}}, $ns;
        }
    }
    
	$packagetype_to_namespace_hash = \%ns_by_pkg;
    return $packagetype_to_namespace_hash;
}

=item tags_by_ns

tags_by_ns()

return hashref of namespaces mapped to their tags

=cut
my $namespace_to_tag_hash;
sub tags_by_ns {
	return $namespace_to_tag_hash if(defined $namespace_to_tag_hash);
    load_namespaces();
	
    # ignore missing tags fields
    no warnings;
    my %hsh = map { ${$_ . "::identifier"} => [ @{${$_ . "::config"}->{packagetypes}}, @{${$_ . "::config"}->{tags}} ]  }
        HTFeed::Version::find_subclasses("HTFeed::Namespace");

	$namespace_to_tag_hash = \%hsh;
    return $namespace_to_tag_hash;
}

=item search_ns_by_tags

search_ns_by_tags(@tags)

return arrayref of namespaces matching all tags in @tags

=cut
sub search_ns_by_tags {
    my $search_tags = shift;
    my @results;
    my $tags_by_ns = tags_by_ns();
    load_namespaces();
    foreach my $ns (keys %{$tags_by_ns}){
        push (@results, $ns)
            if(_tagmatch($tags_by_ns->{$ns},$search_tags));
    }
    return \@results;
}

=item tagmatch

tagmatch($namespace,\@tags)

return true if $namespace matches \@tags

=cut
sub tagmatch {
    my $namespace = shift;
    my $search_tags = shift;

    my $tags_by_ns = tags_by_ns();
    return 1 if(_tagmatch($tags_by_ns->{$namespace},$search_tags));
    return;
}

sub _tagmatch {
    my $actual = shift;
    my $expected = shift;

    my $ok = 1;
    foreach my $tag (@$expected) {
        if(!grep { $_ eq $tag } @$actual) {
            $ok = 0;
            last;
        }
    }

    return $ok;
}

1;

__END__

#======


#################### main pod documentation begin ###################
## Below is the stub of documentation for your module. 
## You better edit it!


=head1 NAME

HTFeed - HathiTrust repository toolkit

=head1 SYNOPSIS

  use HTFeed;
  blah blah blah


=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
I you are reading this, the real docs have not been added here yet

Blah blah blah.


=head1 USAGE



=head1 BUGS



=head1 SUPPORT



=head1 HISTORY

1.0.0 Some Future Data
    - first public release

=head1 AUTHOR

    Library IT - Core Services
    University of Michigan
    lit-cs-ingest@umich.edu
    http://www.lib.umich.edu/

=head1 COPYRIGHT

Copyright (c) 2010-2012 The Regents of the University of Michigan. All rights
reserved. This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

perl(1).

=cut

#################### main pod documentation end ###################


1;

__END__
