package HTFeed;

use warnings;
use strict;
no strict 'refs';

use HTFeed::Version qw(:no_getopt);

my $loaded_namespaces = 0;
my $loaded_pkgtypes = 0;
my $loaded_google_pkgtype = 0;

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

    my $google_lib = "$ENV{FEED_HOME}/google/lib/HTFeed/PackageType";
    if(!$loaded_google_pkgtype) {
      if (-d $google_lib) {
        use lib "$ENV{FEED_HOME}/google/lib";
        HTFeed::PackageType->load_all_subclasses($google_lib,'HTFeed/PackageType') if(-d "$google_lib");
      }
      $loaded_google_pkgtype = 1;
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
        HTFeed::find_subclasses("HTFeed::Namespace");

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

1;

__END__
