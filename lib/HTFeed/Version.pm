package HTFeed::Version;

use warnings;
use strict;
no strict 'refs';

use Getopt::Long qw(:config pass_through no_ignore_case);

use HTFeed::Config qw(get_config);
use HTFeed::PackageType;
use HTFeed::Namespace;

use base qw( Exporter );
our @EXPORT_OK = qw( get_feed_version_number tagmatch search_ns_by_tags );

our $VERSION = 'Unknown';

{
    my $found_version;

    my $feed_home = get_config('feed_home');
    
    if(defined $feed_home) {
        my $version_file = $feed_home . '/bin/rdist.timestamp';
        if (-e $version_file){
            open(my $fh, '<', $version_file);
            my $version_string = <$fh>;
            close $fh;
            chomp $version_string;
            $version_string =~ /^feed_v(.+)$/;
            $found_version = $1;
        }
    }
    $VERSION = $found_version
        if (defined $found_version);
}

sub import{
    my $self = shift;
    $self->SUPER::export_to_level(1, $self, @_);

    my ($short, $long);
    GetOptions ( "version" => \$short, "Version" => \$long );
    long_version() and exit 0 if ($long);
    short_version() and exit 0 if ($short);
}

sub short_version{
    print "Feed, the HathiTrust Ingest System. Feeding the Elephant since 2010.\n";
    print "v$VERSION\n";
}

sub find_subclasses {
    my $class = shift;

    return grep { eval "$_->isa('$class') and '$_' ne '$class'" }
        (map { s/\//::/g; s/\.pm//g; $_} 
            ( grep { /.pm$/ } (keys %INC)));
}
sub long_version{
    short_version();
    # convert paths to module names; return all those that are a subclass
    # of the given class

    print "\n*** Loaded Namespaces ***\n";
    print join("\n",map {id_desc_info($_)} ( sort( find_subclasses("HTFeed::Namespace") )));
    print "\n*** Loaded PackageTypes ***\n";
    print join("\n",map {id_desc_info($_)} ( sort( find_subclasses("HTFeed::PackageType") )));
    print "\n*** Loaded Stages ***\n";
    print join("\n",sort( find_subclasses("HTFeed::Stage")));
    print "\n";
}


sub namespace_ids {
    return map {${$_ . "::identifier"}} (sort(find_subclasses("HTFeed::Namespace")));
}

sub pkgtype_ids {
    return map {${$_ . "::identifier"}} (sort(find_subclasses("HTFeed::PackageType")));
}

sub id_desc_info {
    my $class = shift;
    my $key = ${$class . "::identifier"};
    my $desc = ${$class . "::config"}->{description};
    return "$class - $key - $desc";
}

sub nspkg {
    return map {$_ => {id_desc_info($_)}} find_subclasses("HTFeed::Namespace");
}

=item pkg_by_ns

pkg_by_ns()

return hashref of namespaces mapped to their packagetypes

=cut
my $namespace_to_packagetype_hash;
sub pkg_by_ns {
	return $namespace_to_packagetype_hash if(defined $namespace_to_packagetype_hash);

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

sub get_feed_version_number{
    return $VERSION;
}

1;

__END__

=Synopsys
# in script.pl
use HTFeed::Version;

# at command line
script.pl -version
=Description
use in a pl to enable -version and -Version flags
=cut
