use warnings;
use strict;

my $process_id = $$;
my $subprocesses = 0;
my %locks = ();

my $volumes_in_process_limit = 5;

while(! exit_condition()){
    while (($subprocesses < $volumes_in_process_limit) and (my $job = get_next_job())){
        spawn($job);
    }
    refresh_kid();
}
print "Terminating\n";
while ($subprocesses){
    refresh_kid();
}

# fork, lock job, increment $subprocess
sub spawn{
    my ($job) = @_;
    my $pid = fork();
    if ($pid){
        # parent
        $subprocesses++;
        $locks{$pid} = $job;
        print "LOCK $job to $pid! $subprocesses in flight\n";
    }
    elsif ( defined $pid ) {
        run_stage($job);
        exit(0);
    }
    else{
        die("Couldn't fork: $!");
    }
}

# wait, spawns refreshed job for kid's volume if possible
# else decrement $subprocess and release lock
sub refresh_kid{
    my $pid = wait();
    if ($pid > 0){
        print "$pid done\n";
        $subprocesses--;
        if (my $job = HTFeed::DBTools::release_if_done($namespace,$objid)){
            spawn($job); # get refreshed job without releasing lock
        }
        else{
            delete $locks{$pid};
        }
    }
}

# determine if we are done
sub exit_condition{
    return;
}

sub get_next_job{
    my $job;
    while ($job = $queue_sth->fetchrow_arrayref()){
        return $job if _lock_check($job);
    }
    _fill_queue();
    $queue_sth = HTFeed::DBTools::get_queued();
    while ($job = $queue_sth->fetchrow_arrayref()){
        return $job if _lock_check($job);
    }
    return;
}

sub _fill_queue{
    my $needed_volumes = $volumes_in_process_limit - $subprocesses;
    if ($needed_volumes > 0){
        HTFeed::DBTools::lock_volumes($needed_volumes);
    }
}

sub _lock_check{
    
}

# run_stage( $packagetype, $namespace, $objid, $status, $failure_count )
sub run_stage {
    my ( $packagetype, $namespace, $objid, $status, $failure_count ) = @_;

    my $volume;
    my $nspkg;
    my $stage;

    eval {
        $volume = HTFeed::Volume->new(
            objid       => $objid,
            namespace   => $namespace,
            packagetype => $packagetype
        );
        $nspkg = $volume->get_nspkg();
        my $stage_map   = $nspkg->get('stage_map');
        my $stage_class = $stage_map->{$status};

        $stage = eval "$stage_class->new(volume => \$volume)";

        $logger->info( "RunStage", @log_common, stage => ref($stage) );
        $stage->run();
    };

    my $err = $@;
    if ( $err and $err !~ /STAGE_ERROR/ ) {
        $logger->error( "UnexpectedError", @log_common, stage => ref($stage), detail => $@ );
    }

    if ($stage and $clean) {
        eval { $stage->clean(); };
        if ($@) {
            $logger->error( "UnexpectedError", @log_common, stage  => ref($stage), detail => $@ );
        }
    }

    # update queue table with new status and failure_count
    my $sth;
    if ( $stage and $stage->succeeded() ) {
        $status = $stage->get_stage_info('success_state');
        $logger->info( "StageSucceeded", @log_common, stage => ref($stage) );
        $sth = HTFeed::DBTools::get_dbh()->prepare(
            q(UPDATE `queue` SET `status` = ? WHERE `ns` = ? AND `pkg_type` = ? AND `objid` = ?;)
        );
    }
    else {
        # failure
        if ( $failure_count >= $failure_limit or not defined $stage) {
            # punt if failure limit exceeded or stage construction failed
            $status = 'punted'; 
        } elsif($stage) {
            my $new_status = $stage->get_stage_info('failure_state');
            $status = $new_status if ($new_status);
        } 

        $logger->info( "StageFailed", @log_common, stage => ref($stage) );

        if ( $status eq 'punted' ) {
            $logger->info( "VolumePunted", @log_common );
            eval {
                $volume->clean_all() if $volume and $clean;
            };
            if($@) {
                $logger->error( "UnexpectedError", @log_common, detail => "Error cleaning volume: $@");
            }
        }
        $sth = HTFeed::DBTools::get_dbh()->prepare(
            q(UPDATE `queue` SET `status` = ?, failure_count=failure_count+1 WHERE `ns` = ? AND `pkg_type` = ? AND `objid` = ?;)
        );
    }
    $sth->execute( $status, $namespace, $packagetype, $objid );
    
    $stage->clean_punt() if ($stage and $status eq 'punted');
}

END{
    # clean up on exit of original pid (i.e. don't clean on END of fork()ed pid) if $clean
    if ($$ eq $pid and $clean){
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
