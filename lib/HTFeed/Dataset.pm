package HTFeed::Dataset;

use warnings;
use strict;

#use File::Copy;
use HTFeed::Config;

use File::Pairtree qw(id2ppath s2ppchars);
#use File::Path qw(make_path);

use HTFeed::Dataset::Stage::UnpackText;
use HTFeed::Dataset::Stage::Pack;
use HTFeed::Dataset::Stage::Collate;

use Log::Log4perl qw(get_logger);

=item add_volume

=cut
sub add_volume{
    my $volume = shift;
    my $htid = $volume->get_identifier;

    # unpack and check consistancy
    my $unpack = HTFeed::Dataset::Stage::UnpackText->new(volume => $volume);
    $unpack->run();
    $unpack->clean();
    return if ($unpack->failed);

    # pack
    my $pack = HTFeed::Dataset::Stage::Pack->new(volume => $volume);
    $pack->run();
    $pack->clean();
    return if ($pack->failed);
    
    # collate
    my $collate = HTFeed::Dataset::Stage::Collate->new(volume => $volume);
    $collate->run();
    $collate->clean();
    return if ($collate->failed);
    
    # success
    return 1;
}

#=item remove_volume
#
#=cut
#sub remove_volume{
#    my $volume = shift;
#    
#}

1;

__END__

