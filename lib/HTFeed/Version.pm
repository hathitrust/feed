package HTFeed::Version;

use warnings;
use strict;
no strict 'refs';

use Getopt::Long qw(:config pass_through no_ignore_case);

use HTFeed::Config qw(get_config);
use HTFeed::PackageType;
use HTFeed::Namespace;
use Exporter;
use base qw(Exporter);

our @EXPORT_OK = qw(namespace_ids pkgtype_ids);
our @EXPORT = qw(namespace_ids pkgtype_ids get_feed_version_number);

my $VERSION = 'unknown';

{
    my $version_file = get_config('feed_app_root') . '/bin/rdist.timestamp';
    if (-e $version_file){
        open(my $fh, '<', $version_file);
        my $version_string = <$fh>;
        close $fh;
        chomp $version_string;
        $version_string =~ /feed_v(\d+\.\d+\.\d+)/;
        $VERSION = $1;
    }
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

    return grep { eval "$_->isa('$class')" }
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
    #print join("\n",map {id_desc_info($_)} ( sort( find_subclasses("HTFeed::Namespace") )));
    
    return map {$_ => {id_desc_info($_)}} HTFeed::Version::find_subclasses("HTFeed::Namespace");
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
