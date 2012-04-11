package HTFeed::RunLite;

use warnings;
use strict;
use Carp;

use HTFeed::StagingSetup;
use HTFeed::Version;
use HTFeed::ServerStatus;
use HTFeed::Stage::Done;

use HTFeed::Log;
use Log::Log4perl qw( get_logger );

use HTFeed::Job;
use Data::Dumper;

use base qw( Exporter );
our @EXPORT_OK = qw( runlite );

my $pid = $$;

my $started = 0;
my $finished = 0;

my $max_kids = 0;

my %kids;

my $volumes;
my $namespace;
my $packagetype;
my $logger;
my $verbose;
my $clean;

my $volume_count;
my $volumes_processed;

my $mk_volume = sub{return};

my %volume_input_types = (
    ns_id  => sub{my $arr = shift; my ($namespace, $id) = @{$arr}; return _mk_vol($packagetype, $namespace, $id)},
    id     => sub{my $id = shift; return _mk_vol($packagetype, $namespace, $id)},
    volume => sub{my $volume = shift; return $volume},
);

sub _mk_vol{
    my ($packagetype, $namespace, $id) = @_;
    return HTFeed::Volume->new(
        objid       => $id,
        namespace   => $namespace,
        packagetype => $packagetype,
    );
}

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
    croak 'runlite can only be invoked once'
        if($started);
    $started++;

    my $args = {
        volumes => undef,
        namespace => undef,
        packagetype => undef,
        threads => 0,
        logger => 'HTFeed::RunLite',
        verbose => 0,
        clean => 1,
        volume_input_type => 'ns_id',
        @_,
    };
    $volumes     = $args->{volumes};
    $namespace   = $args->{namespace};
    $packagetype = $args->{packagetype};
    $logger      = $args->{logger};
    $verbose     = $args->{verbose};
    $clean       = $args->{clean};

    $max_kids = $args->{threads};

    $mk_volume = $volume_input_types{$args->{volume_input_type}}
        or croak "Bad volume_input_type $args->{volume_input_type} specified";

    # wipe staging directories
    HTFeed::StagingSetup::make_stage($clean);

    $volume_count = @{$volumes};
    $volumes_processed = 0;
    print "Processing $volume_count volumes...\n" if($verbose);
    
    while (my $volume = shift @{$volumes}){
        $volumes_processed++;
        print "Processing volume $volumes_processed of $volume_count...\n"
            unless ($volumes_processed % 1000 and $verbose);
        
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
    my $volume_info = shift;
    my $volume;
    
    eval {
        $volume = &{$mk_volume}($volume_info);
    };
    if($@ or !$volume) {
        get_logger($logger)->error( 'Volume instantiation failed', detail => $@ . 'Input: ' . Dumper($volume_info) );
        return;
    }
    
    my $job = HTFeed::Job->new(volume => $volume, callback => sub{return});
    
    while($job){
        $job->run_job($clean);
        $job = $job->successor;
        # reap any children
        while(wait()) { last if $? == -1};
    }

    return;
}

1;

__END__
