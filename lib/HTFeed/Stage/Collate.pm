package HTFeed::Stage::Collate;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use Carp qw(croak);

use HTFeed::Storage::LocalPairtree;
use HTFeed::Storage::LinkedPairtree;
use HTFeed::Storage::PrefixedVersions;
use HTFeed::Storage::ObjectStore;

=head1 NAME

HTFeed::Stage::Collate

=head1 SYNOPSIS

  Deposits object to configured storage back end and verifies that it was
  deposited correctly.

=cut

sub storages {
  my $self = shift;
  return HTFeed::Storage::for_volume($self->{volume});
}

sub run{
    my $self = shift;

    $self->{is_repeat} = 0;

    my @storages = @_;
    @storages = $self->storages unless @storages;

    foreach my $storage (@storages) {

      if( $self->collate($storage))  {
        get_logger->trace("finished collate to $storage, cleaning up");
        $storage->cleanup
      } else {
        get_logger->warn("collate to $storage failed, rolling back");
        $storage->rollback;
      }

      $storage->clean_staging();

      $self->check_errors($storage);
      $self->log_repeat($storage);
    }

    $self->_set_done();
    return $self->succeeded();
}

sub log_repeat {
  my $self = shift;
  my $storage = shift;

  # TODO - move to specific storage class? not really a property of collate as
  # such
  if($storage->{is_repeat}) {
    $self->{is_repeat} = 1;
    $self->set_info('Collating volume that is already in repo');
  }
}

sub collate {
  my $self = shift;
  my $storage = shift;

  get_logger->trace("Starting collate for $storage");

  $storage->validate_zip_completeness &&
  $storage->encrypt &&
  $storage->verify_crypt &&
  $storage->stage &&
  $storage->prevalidate &&
  $storage->make_object_path &&
  $storage->move &&
  $storage->postvalidate &&
  $storage->record_audit
}

sub check_errors {
  my $self = shift;
  my $stage = shift;

  foreach my $error (@{$stage->{errors}}) {
    $self->{failed}++;
    if ( get_config('stop_on_error') ) {
        croak("STAGE_ERROR");
    }
  }
}

sub success_info {
    my $self = shift;
    return "repeat=" . $self->{is_repeat};
}

sub stage_info{
    return {success_state => 'collated', failure_state => 'punted'};
}

sub clean_always{
    my $self = shift;
    $self->{volume}->clean_mets();
    $self->{volume}->clean_zip();
}

sub clean_success {
    my $self = shift;
    $self->{volume}->clear_premis_events();
    $self->{volume}->clean_sip_success();
}

1;
