package HTFeed::Version;

use warnings;
use strict;
no strict 'refs';

use Getopt::Long qw(:config pass_through no_ignore_case);

use HTFeed::Config qw(get_config);
use HTFeed::PackageType;
use HTFeed::Namespace;

our $VERSION = 'Unknown';

{
    my $found_version;

    my $feed_root = get_config('feed_app_root');
    
    if(defined $feed_root) {
        my $version_file = $feed_root . '/bin/rdist.timestamp';
        if (-e $version_file){
            open(my $fh, '<', $version_file);
            my $version_string = <$fh>;
            close $fh;
            chomp $version_string;
            $version_string =~ /feed_v(\d+\.\d+\.\d+)/;
            $found_version = $1;
        }
    }
    $VERSION = $found_version
        if (defined $found_version);
}

sub import{
    my ($short, $long);
    GetOptions ( "version" => \$short, "Version" => \$long );
    long_version() and exit 0 if ($long);
    short_version() and exit 0 if ($short);
}

sub short_version{
    print "Feedr, The HathiTrust Ingest System. Feeding the Elephant since 2010.\n";
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

sub pkg_by_ns {
    my %hsh = map {${$_ . "::identifier"}=>${$_ . "::config"}->{packagetypes}} (sort(find_subclasses("HTFeed::Namespace")));
    return \%hsh;
}

sub ns_by_pkg {
    my $pkg_by_ns = pkg_by_ns();
    my %ns_by_pkg;
    foreach my $ns (keys %{$pkg_by_ns}){
        foreach my $pkg (@{$pkg_by_ns->{$ns}}){
            $ns_by_pkg{$pkg} = []
                unless (defined $ns_by_pkg{$pkg});
            push @{$ns_by_pkg{$pkg}}, $ns;
        }
    }
    
    return \%ns_by_pkg;
}

sub tags_by_ns {
    # ignore missing tags fields
    no warnings;
    my %hsh = map { ${$_ . "::identifier"} => [ @{${$_ . "::config"}->{packagetypes}}, @{${$_ . "::config"}->{tags}} ]  }
        HTFeed::Version::find_subclasses("HTFeed::Namespace");
    return \%hsh;
}

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
