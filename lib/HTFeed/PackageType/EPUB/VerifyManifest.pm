package HTFeed::PackageType::EPUB::VerifyManifest;

use warnings;
use strict;
use IO::Handle;
use IO::File;
use List::MoreUtils qw(any);
use File::Copy qw(move);

use base qw(HTFeed::PackageType::Simple::VerifyManifest);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);

# Verifies that all files listed in the manifest exist and that their checksums
# match those provided in checksum.md5

sub run {
    my $self   = shift;
    my $volume = $self->{volume};

    $self->SUPER::run();

    my $preingest_dir = $volume->get_preingest_directory();
    my $staging_dir = $volume->get_staging_directory();
    foreach my $file (glob("$preingest_dir/*.{pdf,epub}")) {
      move($file,$staging_dir);
    }
}

sub stage_info{
    return {success_state => 'manifest_verified', failure_state => 'punted'};
}


1;

__END__
