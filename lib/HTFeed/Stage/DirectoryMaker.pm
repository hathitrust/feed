package HTFeed::Stage::DirectoryMaker;

use warnings;
use strict;
use Carp;
use Filesys::Df;

use base qw(HTFeed::Stage);
use HTFeed::Config;

=head1 NAME

HTFeed::Stage::DirectoryMaker

=head1 DESCRIPTION

makes staging directory, either in ram or on disk. if stage_on_disk returns
true, creates it on disk rather than ram and symlinks to ram.

=cut

sub make_staging_directories{
    my $self = shift;
    my $volume = $self->{volume};

    foreach my $stage_type (qw(preingest staging zip)) {
        my $stage_dir = eval "\$volume->get_${stage_type}_directory()";
        next unless $stage_dir and $stage_dir ne '';

        if (! -d $stage_dir)  {
          mkdir($stage_dir)
            or croak("Can't mkdir $stage_dir: $!");
        }
    }
}

sub run {
    my $self = shift;
    $self->make_staging_directories();
}

1;
