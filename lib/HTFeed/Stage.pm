package HTFeed::Stage;

# abstract class, children must implement following methods:
# run
# children may also override clean_* methods as needed

use warnings;
use strict;
use base qw(HTFeed::SuccessOrFailure);

use Carp;
use File::Find;
use HTFeed::Config qw(get_config);
use HTFeed::JobMetrics;
use Log::Log4perl qw(get_logger);
use POSIX qw(ceil);

sub new {
    my $class = shift;

    # make sure we are instantiating a child class, not self
    if ( $class eq __PACKAGE__ ) {
        croak __PACKAGE__ . ' can only construct subclass objects';
    }

    # No class inheriting from HTFeed::Stage needs to instantiate
    # its own $self->{job_metrics} for storing JobMetrics.
    my $self = {
        volume => undef,
        @_,
        has_run => 0,
        failed  => 0,
	job_metrics => HTFeed::JobMetrics->get_instance
    };

    unless ( $self->{volume} && $self->{volume}->isa("HTFeed::Volume") ) {
        croak "$class cannot be constructed without an HTFeed::Volume";
    }

    bless( $self, $class );
    return $self;
}


sub estimate_space{
    my ($file, $multiplier) = @_;
    my $size = -s $file;
    return ceil($size * $multiplier);
}

sub dir_size{
    shift if (ref $_[0]);
    my $dir = shift;
    my $size = 0;
    find( sub{$size += -s if -f;}, $dir);
    return $size;
}

# returns information about the stage
# to support this children should impliment stage_info() that returns a hash ref like:
#   {success_state => 'validated', failure_state => 'punted'};
#
# (note: this odd implimentation is to support inheritance nicely)
sub get_stage_info {
    my $self  = shift;
    my $field = shift;

    if ($field) {
        return $self->stage_info()->{$field};
    }
    return $self->stage_info();
}

# abstract
# sub run{}

sub _set_done {
    my $self = shift;
    $self->{has_run}++;
    return $self->{has_run};
}

sub failed {
    my $self = shift;
    return $self->{failed} if $self->{has_run};
    
    # stage didn't finish running.
    return 1;
}

sub set_error {
    my $self  = shift;
    my $error = shift;
    $self->{failed}++;

    # log error w/ l4p
    my $logger = get_logger( ref($self) );
    $logger->error(
        $error,
        namespace => $self->{volume}->get_namespace(),
        objid     => $self->{volume}->get_objid(),
        stage     => ref($self),
        @_
    );

    if ( get_config('stop_on_error') ) {
        croak("STAGE_ERROR");
    }
}

sub set_info {
    my $self    = shift;
    my $message = shift;

    my $logger = get_logger( ref($self) );
    $logger->info(
        'Info',
        detail    => $message,
        namespace => $self->{volume}->get_namespace(),
        objid     => $self->{volume}->get_objid(),
        stage     => ref($self),
        @_
    );
}

sub clean {
    my $self    = shift;
    my $success = $self->succeeded();

    if ($success) {
        $self->clean_success();
    }
    else {
        $self->clean_failure();
    }

    $self->clean_always();
}

sub clean_success {
    return;
}

sub clean_failure {
    return;
}

sub clean_always {
    return;
}

sub clean_punt{
    my $self = shift;
    my $volume = $self->{volume};
    
    $volume->clean_mets();
    $volume->clean_zip();
    $volume->clean_unpacked_object();
    $volume->clean_preingest();
    $volume->clean_sip_failure();
    
    return;
}

sub force_failed_status{
    my $self = shift;
    my $failed = shift;
    
    croak "force_failed_status is only for testing" unless (get_config("debug"));

    $self->_set_done();
    $self->{failed} = $failed;
    
    return;
}

sub success_info {
    my $self = shift;
    return "";
}

1;

__END__

=head1 NAME

HTFeed::Stage - Manage Feed ingest stages

=head1 SYNOPSIS

Main class for Feed stage management

=head1 DESCRIPTION

Stage.pm provides the main methods for running the ingest process stages defined in a PackageType configuration file.
The main stages classses are defined under HTFeed/Stage, and a given PackageType may have its own stages, as well.

=head2 METHODS

=over 4

=item new()

Instantiate the class...

=item clean_success()

Do cleaning that is appropriate after success
Run automatically by clean() when needed

=item estimate_space()

estimate_space($file, $multiplier);

=item get_stage_info()

Returns information about a stage

my $info_hash = $stage->get_stage_info();
my $info_item = $stage->get_stage_info('item_name');

=item clean()

run this to do appropriate cleaning after run()
this generally should not be overriden,
instead override clean_success() and clean_failure()

$stage->clean();

=item force_failed_status()

force stage to report success/failure

$stage->force_failed_status($failed)

=item success_info()

returns additional info to log on success.

=item dir_size()

Return the size of a directory

=item clean_punt()

Cleaning to do on punt
NOT run by clean(), because clean() doesn't know you punted

=item failed()

Return true if failed, false if succeeded
Set error and return true if ! $self->{has_run}

=item clean_always()

Do cleaning independent of success
Run automatically by clean() when needed

=item set_error()

Set fail, log errors

=item set_info()

Log info message

=item clean_failure()

Do cleaning that is appropriate after failure
Run automatically by clean() when needed

=cut
