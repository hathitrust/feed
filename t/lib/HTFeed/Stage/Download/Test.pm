package HTFeed::Stage::Download::Test;

use warnings;
use strict;

use base qw(HTFeed::Test::Class);
use HTFeed::Test::Support qw(get_fake_stage);
use Test::More;
use File::Temp ();
use Digest::MD5;

use HTFeed::Stage::Download;

sub download : Test(1){
    my $self = shift;

    my $url = 'http://ia700204.us.archive.org/20/items/livesandspeeches00howeiala/livesandspeeches00howeiala_files.xml';
    my $filename = 'livesandspeeches00howeiala_files.xml';
    my $md5_expected = 'a03326afd33df0eae199aec57e3bf5c4';
    
    my $temp_dir = File::Temp->newdir();
    
    HTFeed::Stage::Download::download(get_fake_stage(), url => $url, path => $temp_dir, filename => $filename);

    my $digest = Digest::MD5->new();
    open(my $fh, '<', "$temp_dir/$filename");
    binmode $fh;
    $digest->addfile($fh);
    my $md5_found = $digest->hexdigest();
    
    is ($md5_expected, $md5_found);
}

1;

__END__
