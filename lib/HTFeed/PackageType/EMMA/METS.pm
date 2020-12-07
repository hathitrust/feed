#!/usr/bin/perl

package HTFeed::PackageType::EMMA::METS;
use strict;
use warnings;
use HTFeed::METSFromSource;
use base qw(HTFeed::METSFromSource);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        @_,
    );
    $self->{profile} = "http://www.hathitrust.org/documents/hathitrust-emma-mets-profile1.0.xml";
    $self->{required_events} = ["creation","message digest calculation","virus scan","ingestion"];

    return $self;
}

sub _add_sourcemd {
  # noop - do not add source metadata
}

sub _add_dmdsecs {

  my $self = shift;
  my $mets   = $self->{mets};
  my $volume = $self->{volume};

  # Import the source dmdSecs as it is
  my $src_mets_xpc   = $volume->get_source_mets_xpc();
  my @dmdsec_nodes = $src_mets_xpc->findnodes("//mets:dmdSec");

  if ( !@dmdsec_nodes ) {
      $self->set_error(
          "MissingField",
          file        => $volume->get_source_mets_file(),
          field      => 'mets:dmdSec',
          description => "Can't find dmdSec in source METS"
      );
  }

  foreach my $dmdsec (@dmdsec_nodes) {
    $mets->add_dmd_sec( $dmdsec );
  }

}

1;
