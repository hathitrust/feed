package HTFeed::Run;

use warnings;
use strict;

use base qw(Exporter);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use HTFeed::Namespace;
use HTFeed::DBTools qw(update_queue);

use Filesys::Df;

our @EXPORT = qw(run_job);

# run_job( $job, [$clean], [$force_failed_status])
sub run_job {
    my $job = shift;
    my $clean = shift;
    my $force_failed_status = shift;

    my $stage;

    eval {

        $stage = $job->stage;
        
#        # check if there is space on ramdisk
#        my $required_size = $stage->ram_disk_size();
#        
#        if ($required_size){ # no need to check if $required_size == 0
#            if ($required_size > get_config('ram_disk_max_job_size')){
#                # there isn't space to do this in memory, do it on disk
#                $stage->set_run_on_disk();
#            }
#            elsif( (df(get_config('ram_disk')){bfree} * get_config('ram_fill_limit')) < $ram_disk_size ){
#                # there isn't space to do this at the moment, but there will be
#
#            }
#        }

        get_logger()->info( 'RunStage', objid => $job->id, namespace => $job->namespace, stage => $job->stage_class );
        $stage->run();
    };

    my $err = $@;
    if ( $err and $err !~ /STAGE_ERROR/ ) {
        get_logger()->error( 'UnexpectedError', objid => $job->id, namespace => $job->namespace, stage => $job->stage_class, detail => $@ );
    }

    if (defined $force_failed_status){
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
