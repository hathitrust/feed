package HTFeed::Job;

#use Moose;
use Any::Moose;
use HTFeed::Volume;
use HTFeed::Config;
use Carp;

use Log::Log4perl qw(get_logger);

has [qw(pkg_type namespace id)]         => (is => 'ro', isa => 'Str',     lazy_build => 1);
has 'status'                            => (is => 'ro', isa => 'Str',     required => 1, default => 'ready');
has 'callback'                          => (is => 'ro', isa => 'CodeRef', required => 1);
has 'failure_count'                     => (is => 'rw', isa => 'Str',     required => 1, default => 0);
has 'stage_class'                       => (is => 'ro', isa => 'Maybe[Str]', init_arg => undef, lazy_build => 1);
has 'new_status'                        => (is => 'ro', isa => 'Str',     init_arg => undef, lazy_build => 1);
has '_release'                          => (is => 'ro', isa => 'Bool',    init_arg => undef, lazy_build => 1);
has 'volume'                            => (is => 'ro', isa => 'Object',                     lazy_build => 1);
has 'stage'                             => (is => 'ro', isa => 'Object',  init_arg => undef, lazy_build => 1);

=item new

callback is a coderef to update status of job

must take args as follows:
callback($ns,$id,$status,[$release],[$fail])

=synopsis
HTFeed::Job->new($pkg_type, $namespace, $id, $status, $failure_count, \&callback)
HTFeed::Job->new(   pkg_type => $pkg_type,
                    namespace => $namespace,
                    id => $id,
                    [status => $status,] # defaults to ready
                    [failure_count => $failure_count,] # defaults to 0
                    callback => \&callback)
HTFeed::Job->new(   volume => $volume,
                    [status => $status,] # defaults to ready
                    [failure_count => $failure_count,] # defaults to 0
                    callback => \&callback)
=cut

=item update

uses callback to update job status (usually in the queue db table, but the callback can do whatever you want)
status of this job DOES NOT change from what was defined on instantiation; jobs are not intended to be re-used

=synopsis

$job->update();

=cut
sub update{
    my $self = shift;

    my $stage = $self->stage;
    my $fail = $stage->failed;
    my $new_status = $self->new_status;

    ## TODO: make this a class global or see if it can be better accessed with YAML::Config, etc.
    ## i.e. put it somwhere else, but preferably somthing tidy
    my %release_states = map {$_ => 1} @{get_config('daemon'=>'release_states')};

    my $release = $self->_release;

    get_logger()->info( 'StageSucceeded', objid => $self->id, namespace => $self->namespace, stage => $self->stage_class, detail => $stage->success_info() )
        if (!$fail);
    get_logger()->info( 'StageFailed', objid => $self->id, namespace => $self->namespace, stage => $self->stage_class, detail => 'fatal=' . ($new_status eq 'punted' ? '1' : '0') )
        if ($fail);

    &{$self->{callback}}($self->namespace, $self->id, $new_status, $release, $fail);

    return;
}

sub _build__release{
    my $self = shift;

    my $new_status = $self->new_status;

    ## TODO: make this a class global or see if it can be better accessed with YAML::Config, etc.
    ## i.e. put it somwhere else, but preferably somthing tidy
    my %release_states = map {$_ => 1} @{get_config('daemon'=>'release_states')};

    my $release = 0;
    $release = 1 if (defined $release_states{$new_status});

    return $release;
}

=item clean

runs appropriate cleaning methods

=synopsis

$job->clean();

=cut

sub clean{
    my $self = shift;
    my $stage = $self->stage;

    $stage->clean();
    
    $stage->clean_punt() if ($self->new_status eq 'punted');
    
    return;
}

# this wraps the default constructor to allow non-hash-style args
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    
    # exactly 6 args to construct w/o hash style args
    # 10-12 with hash style args
    if ( @_ == 6 ) {
        my ($pkg_type, $namespace, $id, $status, $failure_count, $callback) = @_;
        return $class->$orig(pkg_type => $pkg_type,
                             namespace => $namespace,
                             id => $id,
                             status => $status,
                             failure_count => $failure_count,
                             callback => $callback);
    }
    else {
        return $class->$orig(@_);
    }
};

sub BUILD{
    my $self = shift;
    my $args = shift;
    
    return
        if( (!$self->has_pkg_type && !$self->has_namespace && !$self->has_id and $self->has_volume) or
            ($self->has_pkg_type && $self->has_namespace && $self->has_id and !$self->has_volume) );

    croak 'Error instantiating Job: Must specify namespace, id, and packagetype, OR specify volume object. Must not specify both.';
}

sub _build_volume{
    my $self = shift;
    #warn "building volume";
    return HTFeed::Volume->new(
        objid       => $self->id,
        namespace   => $self->namespace,
        packagetype => $self->pkg_type,
    );
}

sub _build_namespace {
	my $self = shift;
    return $self->volume->get_objid;
}
sub _build_pkg_type {
	my $self = shift;
    return $self->volume->get_packagetype;
}
sub _build_id {
	my $self = shift;
    return $self->volume->get_objid;
}

sub _build_stage_class{
    my $self = shift;

    my $class = $self->volume->next_stage($self->status);

    return $class;
}

sub _build_stage{
    my $self = shift;
    
    my $class = $self->stage_class;
    my $volume = $self->volume;
    
    return eval "$class->new(volume => \$volume)";
}

sub _build_new_status{
    my $self = shift;
    
    my $stage = $self->stage;
    
    my $success = $stage->succeeded;
    my $new_status = $success ? 
        $stage->get_stage_info('success_state') : $stage->get_stage_info('failure_state');
    $new_status = 'punted'
        if((! $success) and ($self->failure_count >= get_config('failure_limit')));

    # punt if next status is undefined
    $new_status = 'punted' unless $new_status;

    return $new_status;
}

=item runnable
returns 1 if status successfully maps to a stage in the volume's stage map, else false
=cut
sub runnable{
    my $self = shift;
    return unless $self->stage_class;
    return 1;
}

=synopsis

All options:
 $self->run( [$clean], [$force_failed_status]);
Ususal:
 $self->run( 1 );
Force success:
 $self->run( $clean, 0 );
Force failure:
 $self->job( $clean, 1 );

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

    # handle fake status set in unit tests
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

=item successor
returns a new Job object to execute next stage

returns false if we have reached a release state
=cut
sub successor {
    my $self = shift;

	return if($self->_release());

    my $failure_count = $self->failure_count + $self->stage->failed;
    my $status = $self->new_status;

    my $successor = HTFeed::Job->new(volume => $self->volume,
                    status => $self->new_status,
                    failure_count => ($failure_count),
                    callback => $self->callback);
	
	return $successor;
}

1;

__END__

