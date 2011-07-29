package HTFeed::Run;

use warnings;
use strict;

use base qw(Exporter);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use HTFeed::Namespace;
use Filesys::Df;

our @EXPORT = qw(run_job);

=item run_job

Run a job object, should catch and log any errors that are thrown in the process.

=synopsis

All options:
 run_job( $job, [$clean], [$force_failed_status]);
Ususal:
 run_job( $job, 1 );
Force success:
 run_job( $job, $clean, 0 );
Force failure:
 run_job( $job, $clean, 1 );

=cut
sub run_job {
    my $job = shift;
    my $clean = shift;
    my $force_failed_status = shift;

    my $stage;

    eval {
        $stage = $job->stage;
        
        get_logger()->info( 'RunStage', objid => $job->id, namespace => $job->namespace, stage => $job->stage_class );

        $stage->run();
    };

    my $err = $@;
    if ( $err and $err !~ /STAGE_ERROR/ and $err !~ /VOLUME_ERROR/) {
        get_logger()->error( 'UnexpectedError', objid => $job->id, namespace => $job->namespace, stage => $job->stage_class, detail => $@ );
    }

    if (defined $force_failed_status){
        my $real_failure = $stage->failed;
        my $fake_fail_word = $force_failed_status ? 'FAILURE' : 'SUCCESS';
        my $real_fail_word = $real_failure ? 'FAILURE' : 'SUCCESS';
        my $warning = "Forced stage staus: $fake_fail_word Real stage status: $real_fail_word";
        warn $warning;
        $stage->force_failed_status($force_failed_status);
    }

    if ($stage and $clean) {
        eval { $job->clean(); };
        if ($@) {
            get_logger()->error( 'UnexpectedError', objid => $job->id, namespace => $job->namespace, stage => $job->stage_class, detail => $@ );
        }
    }

    # update queue table with new status and failure_count
    $job->update();

}

1;

__END__
