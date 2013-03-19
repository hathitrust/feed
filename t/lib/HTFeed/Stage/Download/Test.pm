package HTFeed::Stage::Download::Test;

use warnings;
use strict;

use base qw(HTFeed::Test::Class);
use HTFeed::Test::Support qw(get_fake_stage);
use Test::More;
use File::Temp qw(mkdtemp);
use File::Path qw(remove_tree);
use Digest::MD5;

use HTFeed::Stage::Download;

sub download : Test(1){
    my $self = shift;

    my $url = 'http://www.archive.org/download/livesandspeeches00howeiala/livesandspeeches00howeiala_files.xml';
    my $filename = 'livesandspeeches00howeiala_files.xml';
    my $md5_expected = '11caa9b5c4acbe9c1abdeaaa9f55ecf6';
    
    my $temp_dir = mkdtemp("/tmp/feed_test_XXXXX");
    
    HTFeed::Stage::Download::download(get_fake_stage(), url => $url, path => $temp_dir, filename => $filename);

    my $digest = Digest::MD5->new();
    open(my $fh, '<', "$temp_dir/$filename");
    binmode $fh;
    $digest->addfile($fh);
    my $md5_found = $digest->hexdigest();
    
    is ($md5_expected, $md5_found);
    remove_tree($temp_dir);
}

1;

__END__
