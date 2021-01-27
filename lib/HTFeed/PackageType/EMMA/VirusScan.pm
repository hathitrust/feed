#!/usr/bin/perl

package HTFeed::PackageType::EMMA::VirusScan;

use warnings;
use strict;
use base qw(HTFeed::Stage);

use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use PREMIS::Outcome;
use ClamAV::Client;

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(
      @_,
  );
  my $scanner;
  eval {

    my $clamav_options = get_config('clamav') || {};
    $clamav_options->{'socket_host'} = $ENV{CLAMAV_HOST} if $ENV{CLAMAV_HOST};
    $clamav_options->{'socket_port'} = $ENV{CLAMAV_PORT} if $ENV{CLAMAV_PORT};

    $scanner = ClamAV::Client->new(%$clamav_options);
  };
  $self->{scanner} = $scanner;
  return $self;
}

# Verifies that all content files pass ClamAV virus checks.
sub run {
  my $self   = shift;
  my $volume = $self->{volume};
  my $dest = $volume->get_staging_directory();

  my $scanner = $self->{scanner};
  $scanner->ping();
  die "unable to connect to ClamAV: $@" if $@;

  my $files = $volume->get_all_content_files();
  my $virus_count = 0;
  foreach my $file (@$files) {
    my ($path, $result) = $scanner->scan_path($dest . '/' . $file);
    if (defined $result) {
      $virus_count++;
      $self->set_error("Virus", detail => "Virus detected in $file ($result)");
    }
  }
  $self->_add_virus_scan_event($virus_count == 0);
  $self->_set_done();
  return $self->succeeded();
}

sub stage_info {
  return {success_state => 'scanned', failure_state => 'punted'};
}

sub _add_virus_scan_event {
  my $self      = shift;
  my $succeeded = shift;

  my $outcome = PREMIS::Outcome->new($succeeded ? 'pass' : 'fail');
  $self->{volume}->record_premis_event('virus_scan',
                                       outcome => $outcome,);
}

1;

__END__
