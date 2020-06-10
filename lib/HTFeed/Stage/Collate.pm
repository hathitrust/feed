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
    $self->{is_repeat} = 0;

    my $storage = HTFeed::Storage::LocalPairtree->new(
      volume => $self->{volume},
      collate => $self);

    $storage->stage;
    $storage->validate;
    $storage->link;
    $storage->move;

    return $self->succeeded();
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
