#!/usr/bin/perl

=description
cron_feed.pl ingests packages
=cut

use warnings;
use strict;
use Cwd;

use DBI;

use HTFeed::Version;
use HTFeed::StagingSetup;

use HTFeed::Config qw(get_config);
use HTFeed::Volume;
use HTFeed::Log { root_logger => 'INFO, dbi, screen' };
use HTFeed::DBTools;
use Getopt::Long;
use Pod::Usage;

use Log::Log4perl qw(get_logger);

my $failure_limit            = get_config('failure_limit');
my $volumes_in_process_limit = get_config('volumes_in_process_limit');
my $logger                   = get_logger();

my $debug = 0;
my $clean = 1;
my $wd    = getcwd();

my $result = GetOptions(
    "verbose+" => \$debug,
    "clean!"   => \$clean
) or pod2usage(1);

HTFeed::StagingSetup::make_stage($clean);

# store pid for use in END
my $pid = $$;

my @log_common;

my $subprocesses     = 0;
my $max_subprocesses = $volumes_in_process_limit;

eval {

  OUTER:
    while (HTFeed::DBTools::lock_volumes($volumes_in_process_limit) or HTFeed::DBTools::count_locks() ){
        while ( my $sth = HTFeed::DBTools::get_queued() ) {
            while ( my ( $pkg_type, $ns, $objid, $status, $failure_count ) = $sth->fetchrow_array() ){
                @log_common = ( namespace => $ns, objid => $objid );
                wait_kid() if $subprocesses >= $max_subprocesses;

                if(get_config('fork')) {
                    my $pid = fork();
                    if ($pid) {
                        # parent process
                        $subprocesses++;
                        $logger->warn("Spawned child process $pid, $subprocesses now running\n");
                    }
                    elsif ( defined $pid ) {
                        # child process
                        eval {
                            run_stage( $ns, $pkg_type, $objid, $status, $failure_count );
                        };
                        if ($@) {
                            $logger->error( "UnexpectedError", @log_common, detail => $@ );
                            exit(1);
                        }
                        else {
                            exit(0);
                        }
                    }
                    else {
                        die("Couldn't fork: $!");
                    }
                } else {
                    # not forking - run in parent & don't exit
                    eval {
                        run_stage( $ns, $pkg_type, $objid, $status, $failure_count );
                    };
                    if ($@) {
                        $logger->error( "UnexpectedError", @log_common, detail => $@ );
                    }
                }
            }

            # wait for all subprocesses to return before fetching a new set
            wait_kid() while ($subprocesses);
            
            # release locks on completed and failed volumes
            HTFeed::DBTools::release_completed_locks();
            HTFeed::DBTools::release_failed_locks();
        }
    }
};

if ($@) {
    $logger->error( "UnexpectedError", detail => $@ );
    die($@);
}

sub wait_kid {
    my $pid = wait();
    if ( $pid > 0 ) {
        $logger->warn("Child process $pid finished, $subprocesses now running\n");
        $subprocesses--;
    }
    else {
        $logger->warn("Child processes went away...");
        $subprocesses = 0;
    }
    return 1;
}

# run_stage($ns,$pkg_type,$objid,$status,$failure_count)
sub run_stage {
    my ( $namespace, $packagetype, $objid, $status, $failure_count ) = @_;

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
        HTFeed::DBTools::ingest_log_failure($volume,$stage,$status);
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

__END__

=head1 NAME

cron_feed.pl - Queue-driven ingest tool for HathiTrust

=head1 SYNOPSIS

cron_feed.pl [--noclean] [--verbose]

  Options:
    --clean, --noclean Clean up after each stage, or not. Default is to clean.
    --verbose, -v: Produce logging output on the console. Additional -v options produce more verbose output.

=head1 DESCRIPTION

This program fetches volumes from the queue table and processes them.

=head1 ENVIRONMENT VARIABLES

HTFEED_CONFIG - The default configuration file to use.

=cut
