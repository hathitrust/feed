package HTFeed::Stage::DirectoryMaker;

use warnings;
use strict;
use Carp;

use base qw(HTFeed::Stage);
use HTFeed::Config;

=item ram_disk_size

returns an upper bound on the amount of space the volume requires on disk
to complete all stages.

=cut
sub ram_disk_size {
    die("Subclass must implement ram_disk_size!");
}

=item make_staging_directories

makes staging directory, either in ram or on disk. if stage_on_disk returns
true, creates it on disk rather than ram and symlinks to ram.
 returns staging directory

=cut

sub make_staging_directories{
    my $self = shift;
    my $volume = $self->{volume};
    my $ondisk = $self->stage_on_disk();

    foreach my $stage_type qw(preingest staging zip) {
        my $stage_dir = eval "\$volume->get_${stage_type}_directory()";
        next unless $stage_dir and $stage_dir ne '';
        if($ondisk) {
            my $disk_stage_dir = eval "\$volume->get_${stage_type}_directory(1)";
            mkdir($disk_stage_dir)
                or croak("Can't mkdir $disk_stage_dir: $!");

            symlink($disk_stage_dir,$stage_dir) or croak("Can't symlink $disk_stage_dir,$stage_dir: $!");
        } else {
            mkdir($stage_dir)
                or croak("Can't mkdir $stage_dir: $!");
        }
    }
}

sub run {
    my $self = shift;
    $self->make_staging_directories();
}

=item stage_on_disk

return a decision to stage on disk or not; by default based
on $self->ram_disk_size()

=cut

sub stage_on_disk{
    my $self = shift;
    return 1 if (get_config('ram_disk_max_job_size') < $self->ram_disk_size());
    return;
}

1;
