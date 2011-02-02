package HTFeed::Version;

use warnings;
use strict;

use Getopt::Long qw(:config pass_through no_ignore_case);

use HTFeed::Config qw(get_config);
use HTFeed::PackageType;
use HTFeed::Namespace;
use Exporter;
use base qw(Exporter);

our @EXPORT_OK = qw(namespace_ids pkgtype_ids);


sub import{
    my ($short, $long);
    GetOptions ( "version" => \$short, "Version" => \$long );
    long_version() and exit 0 if ($long);
    short_version() and exit 0 if ($short);
}

sub short_version{
    print "Feedr, The HathiTrust Ingest System. Feeding the Elephant since 2010.\n";
    print "v0.1\n";
}

sub long_version{
    short_version();

    my @ns_keys = grep(m|^HTFeed/Namespace/\w+\.pm|, keys %INC);
    my @pt_keys = grep(m|^HTFeed/PackageType/\w+\.pm|, keys %INC);

    print "\n*** Loaded Namespaces ***\n";
    print join("\n",map {packageify($_)} sort @ns_keys);
    print "\n*** Loaded PackageTypes ***\n";
    print join("\n",map {packageify($_)} sort @pt_keys);
    print "\n";
}

sub namespace_ids {
    my @ns_keys = grep(m|^HTFeed/Namespace/\w+\.pm|, keys %INC);
    return map {file_identifier($_)} sort @ns_keys;

}

sub pkgtype_ids {
    my @pt_keys = grep(m|^HTFeed/PackageType/\w+\.pm|, keys %INC);
    return map {file_identifier($_)} sort @pt_keys;
}

sub packageify{
    no strict 'refs';
    my $string = shift;
    $string =~ s/\//::/g;
    $string =~ s/\.pm//g;
    my $key = ${$string . "::identifier"};
    return "$string - $key";
}

sub file_identifier {
    no strict 'refs';
    my $string = shift;
    $string =~ s/\//::/g;
    $string =~ s/\.pm//g;
    my $key = ${$string . "::identifier"};
    return "$key";
}


1;

__END__

=Synopsys
# in script.pl
use HTFeed::Version;

# at command line
script.pl -version
=Descriptoin
use in a pl to enable -version and -Version flags
=cut
