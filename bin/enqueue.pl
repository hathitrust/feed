#!/usr/bin/perl

use warnings;
use strict;
use HTFeed::DBTools;
use HTFeed::Volume;
use Getopt::Long;

my $one_line = 0; # -1
my $dot_format = 0; # -d
my $reset = 0; # -r

# read flags
GetOptions(
    "1" => \$one_line,
    "d" => \$dot_format,
    "r" => \$reset,
);

die '-1 and -d flage incompatible' if ($one_line and $dot_format);

my $in_file;
$in_file = pop unless $one_line;
my $default_packagetype = shift;
my $default_namespace = shift;

my @volumes;

# handle -1
if ($one_line) {
    my $objid = shift;
    unless( $default_packagetype and $default_namespace and $objid ){
        die 'Must specify namespace, packagetype, and objid when using -1 option';
    }

    push @volumes, HTFeed::Volume->new(packagetype => $default_packagetype, namespace => $default_namespace, objid => $objid);
    print "found: $default_packagetype $default_namespace $objid\n";

    HTFeed::DBTools::enqueue(\@volumes);
    exit 0;
}

open INFILE, '<', $in_file or die $!;

# handle -d
if ($dot_format) {
    die 'must specify packagetype when using -d option' if(! $default_packagetype);
    while (<INFILE>) {
        # simplified, lines should match /(.*)\.(.*)/
        $_ =~ /^([^\.\s]*)\.([^\s]*)$/;
        my ($namespace,$objid) = ($1,$2);
        unless( $namespace and $objid ){
            die "Bad syntax near: $_";
        }

        push @volumes, HTFeed::Volume->new(packagetype => $default_packagetype, namespace => $namespace, objid => $objid);
        print "found: $default_packagetype $namespace $objid\n";
    }
}

if (! $dot_format) {
    while (<INFILE>) {
        my @words = split;
        my $objid = pop @words;
        my $namespace = (pop @words or $default_namespace);
        my $packagetype = (pop @words or $default_packagetype);
        unless( $packagetype and $namespace and $objid ){
            die "Missing parameter near: $_";
        }

        push @volumes, HTFeed::Volume->new(packagetype => $packagetype, namespace => $namespace, objid => $objid);
        print "found: $packagetype $namespace $objid\n";
    }
}

HTFeed::DBTools::enqueue(\@volumes);

__END__
=Synopsis
enqueue.pl [-r] [-d] [namespace | namespace packagetype | -1 namespace packagetype objid] [infile]

-d dot format infile - all lines of infile are expected to be of the form namespace.objid. Not compatible with -1 option

-1 only one volume, read from command line and not infile

-r reset - resets volumes in list to ready (NOT IMPLIMENTED)

volume_list contains rows like this:
packagetype namespace objid
namespace objid
objid
(styles my be mixed as long as defaults are provided on the command line)

or with -d like this:
namespace.objid
=cut

