package HTFeed::Stage::StorageMigrate;

use warnings;
use strict;

use base qw(HTFeed::Stage::Collate);
use HTFeed::Config qw(get_config);

use HTFeed::Stage::Collate;

=head1 NAME

  HTFeed::Stage::StorageMigrate

=head1 SYNOPSIS

  Collates object to alternate storage configuration specified by
  'storage_migrate' config key; typically used for migrating from one storage
  back-end to another

=cut

sub storages {
  my $self = shift;
  return HTFeed::Storage::for_volume($self->{volume},'storage_migrate');
}

sub log_repeat {
  # not necessary for storage migration
}

sub stage_info{
    return {success_state => 'migrated', failure_state => 'migrate_punted'};
}

sub success_info {
    my $self = shift;
    return "";
}

1;
