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
use HTFeed::Storage::LocalPairtree;

=head1 NAME

HTFeed::Stage::Collate.pm

=head1 SYNOPSIS

	Base class for Collate stage
	Establishes pairtree object path for ingest

=cut

sub run{
    my $self = shift;

    my $storage = shift || HTFeed::Storage::LocalPairtree->new(
      volume => $self->{volume});

    $self->{is_repeat} = 0;

    $self->stage_and_move($storage) &&
      $self->post_move($storage);

    $self->check_errors($storage);
    $self->log_repeat($storage);

    $self->_set_done();
    return $self->succeeded();
}

sub log_repeat {
  my $self = shift;
  my $storage = shift;

  if($storage->{is_repeat}) {
    $self->set_info('Collating volume that is already in repo');
  }
}

sub stage_and_move {
  my $self = shift;
  my $storage = shift;

  $storage->stage &&
  $storage->prevalidate &&
  $storage->make_object_path &&
  $storage->move;
}

sub post_move {
  my $self = shift;
  my $storage = shift;

  if( $storage->postvalidate ) {
    $storage->record_audit && $storage->cleanup;
  } else {
    $storage->rollback;
  }
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
    return "repeat=" . $self->{storage}->{is_repeat};
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
