#!/usr/bin/perl

=description
cron_feed.pl ingests packages
=cut

use warnings;
use strict;
use Cwd;

use DBI;

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

my @log_common;

my $subprocesses     = 0;
my $max_subprocesses = $volumes_in_process_limit;

eval {

  OUTER:
    while (HTFeed::DBTools::lock_volumes($volumes_in_process_limit)
        or HTFeed::DBTools::count_locks() )
    {
        while ( my $sth = HTFeed::DBTools::get_queued() ) {
            while ( my ( $ns, $pkg_type, $objid, $status, $failure_count ) =
                $sth->fetchrow_array() )
            {
                @log_common = ( namespace => $ns, objid => $objid );
                wait_kid() if $subprocesses >= $max_subprocesses;

                if(get_config('fork')) {
                    my $pid = fork();
                    if ($pid) {

                        # parent process
                        $subprocesses++;
                        warn(
    "Spawned child process $pid, $subprocesses now running\n"
                        );
                    }
                    elsif ( defined $pid ) {


                        # child process
                        eval {
                            run_stage( $ns, $pkg_type, $objid, $status,
                                $failure_count );
                        };
                        if ($@) {
                            $logger->error( "UnexpectedError", @log_common,
                                detail => $@ );
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
                        run_stage( $ns, $pkg_type, $objid, $status,
                            $failure_count );
                    };
                    if ($@) {
                        $logger->error( "UnexpectedError", @log_common,
                            detail => $@ );
                    }
                }

            }

            # wait for all subprocesses to return before fetching a new set
            wait_kid() while ($subprocesses);
        }
    }
};

if ($@) {
    $logger->error( "UnexpectedError", $@ );
    die($@);
}

sub wait_kid {
    my $pid = wait();
    if ( $pid > 0 ) {
        warn("Child process $pid finished, $subprocesses now running\n");
        $subprocesses--;
    }
    else {
        warn("Child processes went away...");
        $subprocesses = 0;
    }
    return 1;

}

# run_stage($ns,$pkg_type,$objid,$status,$failure_count)
sub run_stage {
    my ( $namespace, $packagetype, $objid, $status, $failure_count ) = @_;

    my $volume = HTFeed::Volume->new(
        objid       => $objid,
        namespace   => $namespace,
        packagetype => $packagetype
    );
    my $nspkg = $volume->get_nspkg();

    my $stage_map   = $nspkg->get('stage_map');
    my $stage_class = $stage_map->{$status};

    my $stage = eval "$stage_class->new(volume => \$volume)";

    $logger->info( "RunStage", @log_common, stage => ref($stage) );
    eval { $stage->run(); };
    my $err = $@;
    if ( $err and $err !~ /STAGE_ERROR/ ) {
        $logger->error( "UnexpectedError", @log_common, stage => ref($stage), detail => $@ );
    }
    chdir($wd);    # reset working path if changed

    if ($clean) {
        eval { $stage->clean(); };
        if ($@) {
            $logger->error(
                "UnexpectedError",
                @log_common,
                stage  => ref($stage),
                detail => $@
            );
        }
    }

    # update queue table with new status and failure_count
    my $sth;
    if ( $stage->succeeded() ) {
        $status = $stage->get_stage_info('success_state');
        $logger->info( "StageSucceeded", @log_common, stage => ref($stage) );
        $sth =
          HTFeed::DBTools::get_dbh()
          ->prepare(
q(UPDATE `queue` SET `status` = ? WHERE `ns` = ? AND `pkg_type` = ? AND `objid` = ?;)
          );
    }
    else {
        my $new_status = $stage->get_stage_info('failure_state');
        $status = $new_status if ($new_status);
        $logger->info( "StageFailed", @log_common, stage => ref($stage) );
        if ( $failure_count >= $failure_limit ) {
            $status = 'punted';
        }

        if ( $status eq 'punted' ) {
            $logger->info( "VolumePunted", @log_common );
            $volume->clean_all() if $clean;
        }
        $sth =
          HTFeed::DBTools::get_dbh()
          ->prepare(
q(UPDATE `queue` SET `status` = ?, failure_count=failure_count+1 WHERE `ns` = ? AND `pkg_type` = ? AND `objid` = ?;)
          );
    }
    $sth->execute( $status, $namespace, $packagetype, $objid );
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
