#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use warnings;
use strict;
use HTFeed::Log { root_logger => 'INFO, screen' };
use HTFeed::Version;
use Log::Log4perl qw(get_logger);
use HTFeed::Queue;
use HTFeed::Volume;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Copy qw(move);

my $one_line = 0; # -1
my $reset_punted = 0; # -r
my $reset_most = 0; # -R
my $force_reset = 0; # --force-reset
my $reset_level = 0;
my $reuse = 0; # --reuse
my $insert = 0; # -i
my $verbose = 0; # -v
my $quiet = 0; # -q
# Manually-queued stuff is at high priority by default
my $priority = HTFeed::Queue::QUEUE_PRIORITY_HIGH; # -p
my $state = undef; # -s
my $help = 0; # -help,-?
my $use_disallow_list = 1;

my $dot_packagetype = undef; # -d
my $default_packagetype = undef; # -p
my $default_namespace = undef; # -n

# read flags
GetOptions(
    '1' => \$one_line,
    'reset-punted|r' => \$reset_punted,
    'reset|R' => \$reset_most,
    'force-reset' => \$force_reset,
    'insert|i' => \$insert,
    'reuse|u' => \$reuse,
    'verbose|v' => \$verbose,
    'quiet|q' => \$quiet,
    'state|s=s' => \$state,
    'help|?' => \$help,
    'dot-packagetype|d=s' => \$dot_packagetype,    
    'pkgtype|p=s' => \$default_packagetype,
    'namespace|n=s' => \$default_namespace,
    'use-disallow-list|b!' => \$use_disallow_list,
    'priority|y=i' => \$priority,
)  or pod2usage(2);

# highest level wins
$reset_level = 1 if $reset_punted;
$reset_level = 2 if $reset_most;
$reset_level = 3 if $force_reset;


pod2usage(1) if $help;

# check options
pod2usage(-msg => '-1 and -d flags incompatible', -exitval => 2) if ($one_line and $dot_packagetype);
pod2usage(-msg => '-p and -n exclude -d and -1', -exitval => 2) if (($default_packagetype or $default_namespace) and ($one_line or $dot_packagetype));
pod2usage(-msg => 'can only use -u (reuse) when resetting') if ($reuse and !$reset_level);

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
            print "found: $dot_packagetype $namespace $objid\n" if ($verbose);
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
my $queue = HTFeed::Queue->new();

foreach my $volume (@volumes) {
  if(!($reset_level) or $insert) {
    print_result('queued',$volume,$queue->enqueue(volume=>$volume,status=>$state,ignore=>$insert,priority=>$priority,use_disallow_list=>$use_disallow_list));
  }

  if($reset_level){
    print_result('reset',$volume,$queue->reset(volume => $volume, status => $state, priority=>$priority, reset_level => $reset_level));
      
  }

  if($reuse) {
    move_from_failed($volume);
  }
}

sub move_from_failed {
  my $volume = shift;
  
  my $to_ingest_file = $volume->get_sip_location();
  my $failed_file = $volume->get_failure_sip_location();

  if(! -e $failed_file) { 
    log_result($volume,"punted item not reused - $failed_file doesn't exist");
  }

  if(-e $to_ingest_file) { 
    log_result($volume,"punted item not reused - won't overwrite $to_ingest_file");
  }
  
  # failed file does exist, to ingest doesn't, move it back
  $volume->move_sip($volume->get_sip_location());

  if(-e $to_ingest_file) {
    log_result($volume,"punted item reused");
  } else {
    log_result($volume,"punted item not re-used - move failed");
  }

}

sub log_result {
  my $volume = shift;
  my $message = shift;

  if ($verbose or $quiet) {
    print  $volume->get_packagetype() . ' ' . $volume->get_namespace() . ' ' . $volume->get_objid() . ': ' . $message . "\n";
  }
}

sub print_result {
    my $verb = shift;
    my $volume = shift;
    my $result = shift;

    my $message = "";
    # dbi returned true
    if ($result){
        # 0 lines updated
        $message .= "not " if ($result < 1);
        $message .= "$verb";
    }
    # dbi returned false or died
    else {
        $message .= "failure or skipped";
    }

    log_result($volume,$message);
}

__END__

=head1 NAME

    enqueue.pl - add volumes to ingest queue

=head1 SYNOPSIS

enqueue.pl [-v|-q] [-r|-R|-i] [-p packagetype [-n namespace]] [infile]

enqueue.pl [-v|-q] [-r|-R|-i] -d packagetype [infile]

enqueue.pl [-v|-q] [-r|-R|-i] -1 packagetype namespace objid

    INPUT OPTIONS
    -d dot format infile - follow with packagetype
        all lines of infile are expected to be of the form namespace.objid.

    -1 only one volume, read from command line and not infile

    -p,-n - specify packagetype, namespace respectivly.
        incompatible with -d, -1
    
    GENERAL OPTIONS

    -r, --reset-punted - resets punted volumes in list to ready

    -R, --reset - resets punted,collated,rights,done volumes in list to ready

    --force-reset - resets all volumes in list to ready (use with care)

    -u, --reuse - use with one of the reset flags above. Moves items from the
      "failed" area back to "to ingest" (but does not overwrite anything in "to
      ingest")

    -i insert - volumes are added if they are not already in the queue, but no
      error is raised for duplicate volumes

      If the -i flag is specified with the -R or -r option, will first reset
      any punted, etc. volumes.  then enqueue any items not in the queue, 

    -v verbose - verbose output for file parsing - overrides quiet

    -q quiet - skip report
    
    -s state - set initial state to state (e.g. ready, available, etc)

    -y priority - set priority; 3 is high priority, 2 is medium priority, 1 is low priority

    --no-use-disallow-list - ignore the disallow list and force enqueueing of the given volumes

    INFILE - input read fron last arg on command line or stdin
    
    standard infile contains rows like this:
        [[packagetype] namespace] objid
    
    dot-style (-d) infile rows:
        namespace.objid
=cut

