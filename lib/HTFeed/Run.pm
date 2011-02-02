package HTFeed::Run;

use warnings;
use strict;

use base qw(Exporter);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use HTFeed::Namespace;
use HTFeed::DBTools qw(update_queue);

our @EXPORT = qw(run_job can_run_job);

my $failure_limit = get_config('failure_limit');

# can_run_job( $job )
sub can_run_job {
    my $job = shift;
    return ( exists HTFeed::Namespace->new($job->{ns},$job->{pkg_type})->get('stage_map')->{$job->{status}} );
}

# run_job( $job, $clean )
sub run_job {
    my $job = shift;
    my $clean = shift;

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

        get_logger()->info( 'RunStage', objid => $job->{objid}, namespace => $job->{ns}, stage => ref($stage) );
        $stage->run();
    };

    my $err = $@;
    if ( $err and $err !~ /STAGE_ERROR/ ) {
        get_logger()->error( 'UnexpectedError', objid => $job->{objid}, namespace => $job->{ns}, stage => ref($stage), detail => $@ );
    }

    if ($stage and $clean) {
        eval { $stage->clean(); };
        if ($@) {
            get_logger()->error( 'UnexpectedError', objid => $job->{objid}, namespace => $job->{ns}, stage  => ref($stage), detail => $@ );
        }
    }

    # update queue table with new status and failure_count
    if ( $stage and $stage->succeeded() ) {
        # success
        my $status = $stage->get_stage_info('success_state');
        get_logger()->info( 'StageSucceeded', objid => $job->{objid}, namespace => $job->{ns}, stage => ref($stage) );
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

        get_logger()->info( 'StageFailed', objid => $job->{objid}, namespace => $job->{ns}, stage => ref($stage) );

        if ( $status eq 'punted' ) {
            get_logger()->info( 'VolumePunted', objid => $job->{objid}, namespace => $job->{ns} );
            eval {
                $volume->clean_all() if $volume and $clean;
            };
            if($@) {
                get_logger()->error( 'UnexpectedError', objid => $job->{objid}, namespace => $job->{ns}, detail => "Error cleaning volume: $@");
            }
        }
        update_queue($job->{ns}, $job->{objid}, $status, 1);

        ## This makes no sense re: line 170
        $stage->clean_punt() if ($stage and $status eq 'punted');
    }
}

1;

__END__
