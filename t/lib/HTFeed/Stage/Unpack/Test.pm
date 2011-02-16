package HTFeed::Stage::Unpack::Test;

use warnings;
use strict;

use base qw(HTFeed::Test::Class);
use HTFeed::Test::Support qw(get_fake_stage md5_dir);
use Test::More;
use File::Temp qw(mkdtemp);
use File::Path qw(remove_tree);

use HTFeed::Stage::Download;

sub unzip_file : Test(1){
    my $self = shift;

    my $url = 'http://ia700204.us.archive.org/20/items/livesandspeeches00howeiala/livesandspeeches00howeiala_flippy.zip';
    my $filename = 'livesandspeeches00howeiala_flippy.zip';
    my $md5_expected = '7f88762eb06f53482dedc6142a660ef8';

    my $temp_dir = mkdtemp("/tmp/feed_test_XXXXX");

    HTFeed::Stage::Download::download(get_fake_stage(), url => $url, path => $temp_dir, filename => $filename);
    HTFeed::Stage::Unpack::unzip_file(get_fake_stage(), "$temp_dir/$filename", $temp_dir );
    unlink "$temp_dir/$filename";
    
    my $md5_found = md5_dir($temp_dir);
    
    is ($md5_expected, $md5_found);
    remove_tree($temp_dir);
}

sub untgz_file : Test(1){
    my $self = shift;

    my $url = 'http://www.handle.net/hs-source/hcc5.tar.gz';
    my $filename = 'hcc5.tar.gz';
    my $md5_expected = 'fdc4c09d3d6808219eae310bc740e99c';

    my $temp_dir = mkdtemp("/tmp/feed_test_XXXXX");

    HTFeed::Stage::Download::download(get_fake_stage(), url => $url, path => $temp_dir, filename => $filename);
    HTFeed::Stage::Unpack::untgz_file(get_fake_stage(), "$temp_dir/$filename", $temp_dir );
    unlink "$temp_dir/$filename";
    
    my $md5_found = md5_dir($temp_dir);
   
    is ($md5_expected, $md5_found);

    remove_tree($temp_dir);
}

1;

__END__
