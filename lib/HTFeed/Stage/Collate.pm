package HTFeed::Stage::Collate;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);
use HTFeed::VolumeValidator;
use URI::Escape;
use Carp qw(croak);

use HTFeed::Storage::LocalPairtree;
use HTFeed::Storage::VersionedPairtree;

=head1 NAME

HTFeed::Stage::Collate.pm

=head1 SYNOPSIS

	Base class for Collate stage
	Establishes pairtree object path for ingest

=cut

sub storages_from_config {
  my $self = shift;

  my @storages;
  foreach my $storage_config (@{get_config('storage_classes')}) {
    push(@storages, $storage_config->{class}->new(volume => $self->{volume},
                                                 config => $storage_config));
  }

  return @storages;
}

sub run{
    my $self = shift;

    $self->{is_repeat} = 0;

    my @storages = @_;
    @storages = $self->storages_from_config if !@storages;

    foreach my $storage (@storages) {

      if( $self->collate($storage))  {
        $storage->cleanup
      } else {
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

  if($storage->{is_repeat}) {
    $self->{is_repeat} = 1;
    $self->set_info('Collating volume that is already in repo');
  }
}

sub collate {
  my $self = shift;
  my $storage = shift;

  $storage->zipvalidate &&
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

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
