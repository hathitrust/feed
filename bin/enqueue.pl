#!/usr/bin/perl

use warnings;
use strict;
use HTFeed::DBTools;
use HTFeed::Volume;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

my $one_line = 0; # -1
my $reset = 0; # -r
my $force_reset = 0; # -R
my $insert = 0; # -i
my $verbose = 0; # -v
my $quiet = 0; # -q
my $help = 0; # -help,-?

my $dot_packagetype = undef; # -d
my $default_packagetype = undef; # -p
my $default_namespace = undef; # -n

# read flags
GetOptions(
    '1' => \$one_line,
    'r' => \$reset,
    'R' => \$force_reset,
    'i' => \$insert,
    'v' => \$verbose,
    'q' => \$quiet,
    'help|?' => \$help,

    'd=s' => \$dot_packagetype,    
    'p=s' => \$default_packagetype,
    'n=s' => \$default_namespace,
)  or pod2usage(2);

pod2usage(1) if $help;

# check options
pod2usage(-msg => '-1 and -d flags incompatible', -exitval => 2) if ($one_line and $dot_packagetype);
pod2usage(-msg => '-r/-R incompatible with -i', -exitval => 2) if (($reset or $force_reset) and $insert);
pod2usage(-msg => '-p and -n exclude -d and -1', -exitval => 2) if (($default_packagetype or $default_namespace) and ($one_line or $dot_packagetype));

if ($one_line){
    $default_packagetype = shift;
    $default_namespace = shift;
}

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
    # handle -d (read infile in dot format)
    if ($dot_packagetype) {
        while (<>) {
            # simplified, lines should match /(.*)\.(.*)/
            $_ =~ /^([^\.\s]*)\.([^\s]*)$/;
            my ($namespace,$objid) = ($1,$2);
            unless( $namespace and $objid ){
                die "Bad syntax near: $_";
            }

            push @volumes, HTFeed::Volume->new(packagetype => $dot_packagetype, namespace => $namespace, objid => $objid);
            print "found: $default_packagetype $namespace $objid\n" if ($verbose);
        }
    }

    # handle default case (read infile in standard format)
    if (! $dot_packagetype) {
        while (<>) {
            next if ($_ =~ /^\s*$/); # skip blank line
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

=head1 NAME

    enqueue.pl - add volumes to Feedr queue

=head1 SYNOPSIS

enqueue.pl [-v|-q] [-r|-R|-i] [-p packagetype [-n namespace]] [infile]

enqueue.pl [-v|-q] [-r|-R|-i] -d packagetype [infile]

enqueue.pl [-v|-q] [-r|-R|-i] -1 packagetype namespace objid]

    INOUT OPTIONS
    -d dot format infile - follow with packagetype
        all lines of infile are expected to be of the form namespace.objid.

    -1 only one volume, read from command line and not infile

    -p,-n - specify packagetype, namespace respectivly.
        incompatible with -d, -1
    
    GENERAL OPTIONS
    -r reset - resets punted volumes in list to ready

    -R reset force - resets all volumes in list to ready

    -i insert - volumes are added if they are not already in the queue, but no error is raised for duplicate volumes

    -v verbose - verbose output for file parsing - overrides quiet

    -q quiet - skip report

    INFILE - input read fron last arg on command line or stdin
    
    standard infile contains rows like this:
        [[packagetype] namespace] objid
    
    dot-style (-d) infile rows:
        namespace.objid
=cut

