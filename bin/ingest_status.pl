#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use warnings;
use strict;
use HTFeed::Log { root_logger => 'INFO, screen' };
use HTFeed::Version;
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

my $one_line = 0; # -1
my $verbose = 0; # -v
my $quiet = 0; # -q
my $state = undef; # -s
my $priority = undef; # -y
my $help = 0; # -help,-?
my $use_blacklist = 1;
my $dot = 0;

my $default_namespace = undef; # -n

# read flags
GetOptions(
    '1' => \$one_line,
    'verbose|v' => \$verbose,
    'quiet|q' => \$quiet,
    'dot|d' => \$dot,    
    'help|?' => \$help,
    'namespace|n=s' => \$default_namespace,
)  or pod2usage(2);

pod2usage(1) if $help;

# check options
pod2usage(-msg => '-n excludes -d and -1', -exitval => 2) if ($default_namespace) and ($one_line or $dot);

my @volumes;

# handle -1 flag (no infile read, get one object form command line)
if($one_line and $dot) {
    my $htid = shift @ARGV;
    my ($namespace, $objid) = parse_htid($htid);
    push @volumes, HTFeed::Volume->new(packagetype => 'ht', namespace => $namespace, objid => $objid);
}
elsif ($one_line) {
    my $namespace = shift @ARGV;
    my $objid = shift @ARGV;
    unless( $namespace and $objid ){
        die 'Must specify namespace and objid when using -1 option';
    }

    push @volumes, HTFeed::Volume->new(packagetype => 'ht', namespace => $namespace, objid => $objid);
}
else{
    # handle -d (read infile in dot format)
    if ($dot) {
        while (my $htid = <>) {
            my ($namespace,$objid) = parse_htid($htid);

            push @volumes, HTFeed::Volume->new(packagetype => 'ht', namespace => $namespace, objid => $objid);
        }
    }

    # handle default case (read infile in standard format)
    if (! $dot) {
        while (<>) {
            next if ($_ =~ /^\s*$/); # skip blank line
            my @words = split;
            my $objid = pop @words;
            my $namespace = (pop @words or $default_namespace);

            die("namespace missing (specify with -n) (objid was $objid)\n") if not defined $namespace;
            next if !$objid;

            eval {
                push @volumes, HTFeed::Volume->new(packagetype => 'ht', namespace => $namespace, objid => $objid);
            };
            if($@) {
                warn($@);
            }
        }
    }
}

my $dbh = get_dbh();

my $log_sth = $dbh->prepare("select * from log where namespace = ? and id = ? order by timestamp asc");
my $last_err_sth = $dbh->prepare("select * from last_error where namespace = ? and id = ?");
my $queue_sth = $dbh->prepare("select * from queue where namespace = ? and id = ?");

foreach my $volume (@volumes) {

    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();

    $queue_sth->execute($namespace,$objid);
    my $queue_info = $queue_sth->fetchrow_hashref();

    if(not defined $queue_info) {
        print "$namespace.$objid: not in queue\n" ;
        next;
    }

    print "$namespace.$objid: $queue_info->{status}";

    if(!$quiet) {
        my $err_sth;
        print " at $queue_info->{update_stamp}\n" if(!$quiet);

        if($verbose) {
            $err_sth = $log_sth;
        }
        elsif($queue_info->{status} eq 'punted') {
            $err_sth = $last_err_sth;
        }

        if(defined $err_sth) {
            $err_sth->execute($namespace,$objid);
            while(my $row = $err_sth->fetchrow_hashref()) {
                print "  ";
                delete $row->{namespace};
                delete $row->{id};
                if($verbose) {
                    print "$row->{timestamp} $row->{level}: ";
                }
                delete $row->{timestamp};
                delete $row->{level};
                print "$row->{message}; ";
                delete $row->{message};
                print "$row->{detail}; " if defined $row->{detail} and $row->{detail};
                delete $row->{detail};
                foreach my $key (sort(keys(%$row))) {
                    
                    next if not defined $row->{$key} or $row->{$key} eq '';
                    print "$key: $row->{$key}; ";
                }
                print "\n";
            }
        }
    } else {
        print "\n";
    }

}

sub parse_htid {
    my $htid = shift;
    # simplified, lines should match /(.*)\.(.*)/
    $htid =~ /^([^\.\s]*)\.([^\s]*)$/;
    my ($namespace,$objid) = ($1,$2);
    unless( $namespace and $objid ){
        die "Bad syntax near: $htid";
    }
    return($namespace,$objid);
}

__END__

=head1 NAME

    ingest_status.pl - get status of volumes from queue.

=head1 SYNOPSIS

ingest_status.pl [-v|-q] [-n namespace]] [infile]

ingest_status.pl [-v|-q] -d [infile]

ingest_status.pl [-v|-q] -1 namespace objid

    INPUT OPTIONS
    -d dot format infile
        all lines of infile are expected to be of the form namespace.objid.

    -1 only one volume, read from command line and not infile

    -n - specify namespace
        incompatible with -d, -1
    
    GENERAL OPTIONS
    -v verbose - show full log for each volume

    -q quiet - show status for each volume only
    
    INFILE - input read fron last arg on command line or stdin
    
    standard infile contains rows like this:
        [namespace] objid
    
    dot-style (-d) infile rows:
        namespace.objid
=cut

