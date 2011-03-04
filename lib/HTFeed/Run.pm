package HTFeed::Run;

use warnings;
use strict;

use base qw(Exporter);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use HTFeed::Namespace;
use HTFeed::DBTools qw(update_queue);

use Filesys::Df;

our @EXPORT = qw(run_job can_run_job);

# can_run_job( $job )
sub can_run_job {
    my $job = shift;
    return ( exists HTFeed::Namespace->new($job->{namespace},$job->{pkg_type})->get('stage_map')->{$job->{status}} );
}

# run_job( $job, $clean )
sub run_job {
    my $job = shift;
    my $clean = shift;

    my $volume;
    my $stage;

    eval {
        $volume = HTFeed::Volume->new(
            objid       => $job->{id},
            namespace   => $job->{namespace},
            packagetype => $job->{pkg_type},
        );
        my $stage_class = $volume->get_nspkg()->get('stage_map')->{$job->{status}};

        $stage = eval "$stage_class->new(volume => \$volume)";
        
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

        get_logger()->info( 'RunStage', objid => $job->{id}, namespace => $job->{namespace}, stage => ref($stage) );
        $stage->run();
    };

    my $err = $@;
    if ( $err and $err !~ /STAGE_ERROR/ ) {
        get_logger()->error( 'UnexpectedError', objid => $job->{id}, namespace => $job->{namespace}, stage => ref($stage), detail => $@ );
    }

    if ($stage and $clean) {
        eval { $stage->clean(); };
        if ($@) {
            get_logger()->error( 'UnexpectedError', objid => $job->{id}, namespace => $job->{namespace}, stage  => ref($stage), detail => $@ );
        }
    }

    # update queue table with new status and failure_count
    if ( $stage and $stage->succeeded() ) {
        # success
        my $status = $stage->get_stage_info('success_state');
        get_logger()->info( 'StageSucceeded', objid => $job->{id}, namespace => $job->{namespace}, stage => ref($stage) );
        update_queue($job->{namespace}, $job->{id}, $status);
    }
    else {
        # failure
        my $status;
        if ( $job->{failure_count} >= get_config('failure_limit') or not defined $stage) {
            # punt if failure limit exceeded or stage construction failed
            $status = 'punted'; 
        } elsif($stage) {
            my $new_status = $stage->get_stage_info('failure_state');
            $status = $new_status if ($new_status and $new_status ne '');
        } 
        ## TODO: else {unexpected error} ?

        get_logger()->info( 'StageFailed', objid => $job->{id}, namespace => $job->{namespace}, stage => ref($stage) );

        if ( $status eq 'punted' ) {
            get_logger()->info( 'VolumePunted', objid => $job->{id}, namespace => $job->{namespace} );
            eval {
                $volume->clean_all() if $volume and $clean;
            };
            if($@) {
                get_logger()->error( 'UnexpectedError', objid => $job->{id}, namespace => $job->{namespace}, detail => "Error cleaning volume: $@");
            }
        }
        update_queue($job->{namespace}, $job->{id}, $status, 1);

        ## This makes no sense re: line 170
        $stage->clean_punt() if ($stage and $status eq 'punted');
    }
}

1;

__END__
