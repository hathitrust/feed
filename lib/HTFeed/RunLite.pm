package HTFeed::RunLite;

use warnings;
use strict;
use Carp;

use HTFeed::VolumeGroup;
use HTFeed::StagingSetup;
use HTFeed::Version;
use HTFeed::ServerStatus;
use HTFeed::Stage::Done;

use HTFeed::Log;
use Log::Log4perl qw( get_logger );

use HTFeed::Job;
use Data::Dumper;

use base qw( Exporter );
our @EXPORT_OK = qw( runlite runlite_finish );

my $pid = $$;

my $started = 0;
my $finished = 0;

my $max_kids = 0;

my %kids;

my $volumegroup;
my $logger;
my $verbose;
my $clean;

my $volume_count;
my $volumes_processed;

# run end block on SIGINT and SIGTERM
$SIG{'INT'} =
    sub {
        exit;
    };
$SIG{'TERM'} = 
    sub {
        exit;
    };

sub runlite{
    # setup
    croak 'runlite() connot be invoked twice without running runlite_finish()'
        if($started);
    $started++;

    my $args = {
        volumes => undef,
        packagetype => undef,
        volumegroup => undef,

        threads => 0,
        logger => 'HTFeed::RunLite',
        verbose => 0,
        clean => 1,
        @_,
    };

    croak 'Specify only one of volumegroup and volumes'
        if ($args->{volumegroup} and $args->{volumes});
    croak 'Must specify packagetype for volumes argument'
        if ($args->{volumes} and !$args->{packagetype});
    croak 'Must specify one of volumegroup or volumes'
        if ($args->{volumes} and !$args->{packagetype});

    $volumegroup = $args->{volumegroup};
    $logger      = $args->{logger};
    $verbose     = $args->{verbose};
    $clean       = $args->{clean};
    $max_kids = $args->{threads};

    $volumegroup = HTFeed::VolumeGroup->new(ns_objids => $args->{volumes}, packagetype => $args->{packagetype})
        if (!$args->{volumegroup});

    # wipe staging directories
    HTFeed::StagingSetup::make_stage($clean);

    $volume_count = $volumegroup->size();
    $volumes_processed = 0;
    print "$logger: Processing $volume_count volumes...\n" if ($verbose);
    
    while (my $volume = $volumegroup->shift()){
        $volumes_processed++;
        print "$logger: Processing volume $volumes_processed of $volume_count...\n"
            if ($verbose);
        
        # Fork iff $max_kids != 0
        if($max_kids){
            _spawn_worker($volume);
        }
        else{
            # not forking
            _do_work($volume);
        }
    }
    
    # wait for all child procs to finish
    while(scalar(keys %kids) > 0){
        _wait_kid();
    }

    HTFeed::StagingSetup::clear_stage();

    $finished++;
    return;
}

END{
    # clean up is only needed in END block if we exited badly 
    if($started and !$finished){
        # parent kills kids
        if(kill 0, keys %kids){
            print "killing child procs...\n";
            kill 2, keys %kids;
        	sleep 20;
        }

        # clean up on exit of parent process, iff runner was invoked
        HTFeed::StagingSetup::clear_stage()
            if ($$ eq $pid and $started);
        
        #### add clean up from feedd here

    }
}

sub _wait_kid{
    my $pid = wait();
    if ($pid > 0){
        # remove old job from lock table
        delete $kids{$pid};
        get_logger()->trace("$pid finished");
        return $pid;
    }
    return;
}

sub _spawn_worker{
    my $volume = shift;
    
    # wait until we have a spare thread
    if(scalar(keys %kids) >= $max_kids){
        _wait_kid();
    }

    my $pid = fork();

    if ($pid){
        # parent
        $kids{$pid} = 1;
    }
    elsif (defined $pid){
        _do_work($volume);
        exit(0);
    }
    else {
        croak "Couldn't fork: $!";
    }
}

sub _do_work {
    my $volume = shift;
    
    my $job = HTFeed::Job->new(volume => $volume, callback => sub{return});
    
    while($job){
        $job->run_job($clean);
        $job = $job->successor;
        # reap any children
        while(wait()) { last if $? == -1};
    }

    return;
}

# wait() on any remaining children and reset singletons
# croak rather than continue if we are in a bad state
sub runlite_finish {
    croak 'runlite_finish can only run from main thread'
        unless ($pid == $$);

    my $reamining_children = scalar(keys %kids);

    croak "runlite_finish called with $reamining_children remaining"
        if ($reamining_children);

    $started = 0;
    $finished = 0;
    $max_kids = 0;

    %kids = ();

    $volumegroup = undef;
    $logger = undef;
    $verbose = undef;
    $clean = undef;

    $volume_count = undef;
    $volumes_processed = undef;
}

1;

__END__
