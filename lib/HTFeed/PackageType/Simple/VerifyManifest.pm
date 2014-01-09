package HTFeed::PackageType::Simple::VerifyManifest;

use warnings;
use strict;
use IO::Handle;
use IO::File;
use List::MoreUtils qw(any);

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);

# Verifies that all files listed in the manifest exist and that their checksums
# match those provided in checksum.md5

sub run {
    my $self   = shift;
    my $volume = $self->{volume};

    # just use the checksum validation from volume validator
    # parameter is for ignoring that the source METS does not yet
    # exist
    my $vol_val = HTFeed::VolumeValidator->new(volume => $volume);
    # don't try to get source METS; use preingest directory
    my $success = $vol_val->_validate_checksums(0,$volume->get_preingest_directory());

    $self->_set_done();
    return $vol_val->succeeded();
}

sub stage_info{
    return {success_state => 'manifest_verified', failure_state => 'punted'};
}


1;

__END__
