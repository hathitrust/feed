#!/usr/bin/perl

use warnings;
use strict;
use HTFeed::DBTools;
use HTFeed::Volume;
use Getopt::Long qw(:config no_ignore_case);

my $one_line = 0; # -1
my $dot_format = 0; # -d
my $reset = 0; # -r
my $force_reset = 0; # -R
my $insert = 0; # -i
my $verbose = 0; # -v
my $quiet = 0; # -q

# read flags
GetOptions(
    '1' => \$one_line,
    'd' => \$dot_format,
    'r' => \$reset,
    'R' => \$force_reset,
    'i' => \$insert,
    'v' => \$verbose,
    'q' => \$quiet,
);

# check options
die '-1 and -d flags incompatible' if ($one_line and $dot_format);
die '-r/-R incompatible with -i' if (($reset or $force_reset) and $insert);

my $in_file;
$in_file = pop unless $one_line;
my $default_packagetype = shift;
my $default_namespace = shift;

die 'must specify input file' unless ($in_file or $one_line);

my @volumes;

# handle -1 flag (no infile read, get one object form command line)
if ($one_line) {
    my $objid = shift;
    unless( $default_packagetype and $default_namespace and $objid ){
        die 'Must specify namespace, packagetype, and objid when using -1 option';
    }

    push @volumes, HTFeed::Volume->new(packagetype => $default_packagetype, namespace => $default_namespace, objid => $objid);
    print "found: $default_packagetype $default_namespace $objid\n" if ($verbose);
}
else{
    # read infile
    open INFILE, '<', $in_file or die $!;

    # handle -d (read infile in dot format)
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
            print "found: $default_packagetype $namespace $objid\n" if ($verbose);
        }
    }

    # handle default case (read infile in standard format)
    if (! $dot_format) {
        while (<INFILE>) {
            my @words = split;
            my $objid = pop @words;
            my $namespace = (pop @words or $default_namespace);
            my $packagetype = (pop @words or $default_packagetype);
            unless( $packagetype and $namespace and $objid ){
                die "Missing parameter near: $_";
            }

            eval {
                push @volumes, HTFeed::Volume->new(packagetype => $packagetype, namespace => $namespace, objid => $objid);
            };
            if($@) {
                warn($@);
            }
            print "found: $packagetype $namespace $objid\n" if ($verbose);
        }
    }

    close INFILE;
}

# add volumes to queue
my $results;
if($reset or $force_reset){
    $results = HTFeed::DBTools::reset_volumes(\@volumes, $force_reset);
}
else{
    $results = HTFeed::DBTools::enqueue_volumes(\@volumes, $insert);
}

if ($verbose or !$quiet){
    # print report
    my $verb = 'added';
    if ($reset or $force_reset){
        $verb = 'reset';
    }
    foreach my $volume (@volumes){
        print  $volume->get_packagetype() . ' ' . $volume->get_namespace() . ' ' . $volume->get_objid() . ': ';
        my $result = shift @{$results};
        # dbi returned true
        if ($result){
            # 0 lines updated
            print 'not ' if ($result < 1);
            print "$verb \n";
        }
        # dbi returned false or died
        else {
            print "failure or skipped\n";
        }
    }
}
__END__

=head1 SYNOPSIS

enqueue.pl [-v|-q] [-r|-R|-i] [-d] [namespace | namespace packagetype | -1 namespace packagetype objid] [infile]

    -d dot format infile - all lines of infile are expected to be of the form namespace.objid. Not compatible with -1 option

    -1 only one volume, read from command line and not infile

    -r reset - resets volumes in list to ready

    -i insert - volumes are added if they are not already in the queue, but no error is raised for duplicate volumes

    -v verbose - verbose output for file parsing - overrides quiet

    -q quiet - skip report

    volume_list contains rows like this:

    packagetype namespace objid
    namespace objid
    objid

    (styles my be mixed as long as defaults are provided on the command line)

or with -d like this:
namespace.objid

=cut

