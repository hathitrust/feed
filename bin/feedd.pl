use warnings;
use strict;

#use Data::Dumper;

use DBI;

use HTFeed::Version;
use HTFeed::StagingSetup;

use HTFeed::Config qw(get_config);
use HTFeed::Volume;
use HTFeed::Log { root_logger => 'INFO, dbi, screen' };
use HTFeed::DBTools qw(get_queued lock_volumes update_queue);
use Log::Log4perl qw(get_logger);

my $logger = get_logger();

# make clean stage
## TODO: flags
HTFeed::StagingSetup::make_stage(1);

my $process_id = $$;
my $subprocesses = 0;
my @jobs = ();
my %locks_by_key = ();
my %locks_by_pid = ();
my $clean = 1;
my $failure_limit            = get_config('failure_limit');
my $volumes_in_process_limit = get_config('volumes_in_process_limit');

while(! exit_condition()){
    while (($subprocesses < $volumes_in_process_limit) and (my $job = get_next_job())){
        spawn($job);
    }
    wait_kid() or sleep 30;
}
print "Terminating...\n";
while ($subprocesses){
    ## this won't work (yet)
    refresh_kid();
}

# fork, lock job, increment $subprocess
sub spawn{
    my $job = shift;
    my $pid = fork();
    if ($pid){
        # parent
        lock_job($pid, $job);
    }
    elsif ( defined $pid ) {
        # child
        run_stage($job);
        exit(0);
    }
    else{
        die("Couldn't fork: $!");
    }
}

# wait, spawns refreshed job for kid's volume if possible
# else decrement $subprocess and release lock
sub wait_kid{
    my $pid = wait();
    if ($pid > 0){
        # remove old job from lock table
        release_job($pid);
        return $pid;
    }
    return;
}

# determine if we are done
sub exit_condition{
    return;
}

sub get_next_job{
    my $job;

    if ($job = shift @jobs){
        return $job;
    }

    # @jobs is empty, fill it up from db
    fill_queue();
    if ($job = shift @jobs){
        return $job;
    }
    return;
}

sub fill_queue{
    my $needed_volumes = $volumes_in_process_limit - $subprocesses;
    if ($needed_volumes > 0){
        lock_volumes($needed_volumes);
    }
    
    if (my $sth = get_queued()){    
        while(my $job = $sth->fetchrow_hashref()){
            push (@jobs, $job) if (! is_locked($job));
        }
    }
}

sub is_locked{
    my $job = shift;
    return exists $locks_by_key{$job->{ns}}{$job->{objid}};
}

sub lock_job{
    my ($pid,$job) = @_;
    $locks_by_key{$job->{ns}}{$job->{objid}} = $job;
    $locks_by_pid{$pid} = $job;
    $subprocesses++;
    print "LOCK $job->{ns}.$job->{objid} to $pid! $subprocesses in flight\n";
}

sub release_job{
    my $pid = shift;
    my $job = $locks_by_pid{$pid};
    delete $locks_by_pid{$pid};
    delete $locks_by_key{$job->{ns}}{$job->{objid}};
    $subprocesses--;
    print "RELEASE $job->{ns}.$job->{objid} from $pid! $subprocesses in flight\n";
}

# run_stage( $job )
sub run_stage {
    my $job = shift;

    my $volume;
    my $stage;

    eval {
        $volume = HTFeed::Volume->new(
            objid       => $job->{objid},
            namespace   => $job->{ns},
            packagetype => $job->{pkg_type},
        );
        my $stage_class = $volume->get_nspkg()->get('stage_map')->{$job->{status}};

        $stage = eval "$stage_class->new(volume => \$volume)";

        $logger->info( "RunStage", objid => $job->{objid}, namespace => $job->{ns}, stage => ref($stage) );
        $stage->run();
    };

    my $err = $@;
    if ( $err and $err !~ /STAGE_ERROR/ ) {
        $logger->error( "UnexpectedError", objid => $job->{objid}, namespace => $job->{ns}, stage => ref($stage), detail => $@ );
    }

    if ($stage and $clean) {
        eval { $stage->clean(); };
        if ($@) {
            $logger->error( "UnexpectedError", objid => $job->{objid}, namespace => $job->{ns}, stage  => ref($stage), detail => $@ );
        }
    }

    # update queue table with new status and failure_count
    if ( $stage and $stage->succeeded() ) {
        # success
        my $status = $stage->get_stage_info('success_state');
        $logger->info( "StageSucceeded", objid => $job->{objid}, namespace => $job->{ns}, stage => ref($stage) );
        update_queue($job->{ns}, $job->{objid}, $status);
    }
    else {
        # failure
        my $status;
        if ( $job->{failure_count} >= $failure_limit or not defined $stage) {
            # punt if failure limit exceeded or stage construction failed
            $status = 'punted'; 
        } elsif($stage) {
            my $new_status = $stage->get_stage_info('failure_state');
            $status = $new_status if ($new_status);
        } 
        ## TODO: else {unexpected error} ?

        $logger->info( "StageFailed", objid => $job->{objid}, namespace => $job->{ns}, stage => ref($stage) );

        if ( $status eq 'punted' ) {
            $logger->info( "VolumePunted", objid => $job->{objid}, namespace => $job->{ns} );
            eval {
                $volume->clean_all() if $volume and $clean;
            };
            if($@) {
                $logger->error( "UnexpectedError", objid => $job->{objid}, namespace => $job->{ns}, detail => "Error cleaning volume: $@");
            }
        }
        update_queue($job->{ns}, $job->{objid}, $status, 1);

        ## This makes no sense re: line 170
        $stage->clean_punt() if ($stage and $status eq 'punted');
    }
}

END{
    # clean up on exit of original pid (i.e. don't clean on END of fork()ed pid) if $clean
    if (($$ eq $process_id) and $clean){
        # delete everything in staging, except download
        HTFeed::StagingSetup::clear_stage();
        
        # release all locks
        HTFeed::DBTools::reset_in_flight_locks();
        HTFeed::DBTools::release_completed_locks();
        HTFeed::DBTools::release_failed_locks();
    }
}

1;

__END__
