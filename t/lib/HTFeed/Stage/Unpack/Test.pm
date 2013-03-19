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

    my $url = 'http://www.archive.org/download/livesandspeeches00howeiala/livesandspeeches00howeiala.epub';
    my $filename = 'livesandspeeches00howeiala.epub';
    # expected md5 of all the files in the archive catted together
    my $md5_expected = '984a386632512d17a3ce4bbf8c0f4555';

    my $temp_dir = mkdtemp("/tmp/feed_test_XXXXX");

    eval {
        HTFeed::Stage::Download::download(get_fake_stage(), url => $url, path => $temp_dir, filename => $filename);
        HTFeed::Stage::Unpack::unzip_file(get_fake_stage(), "$temp_dir/$filename", $temp_dir );
        unlink "$temp_dir/$filename";

        my $md5_found = md5_dir($temp_dir);
    
        is ($md5_found, $md5_expected);
    };

    # catch exception, clean up & rethrow
    my $err = $@;
    remove_tree($temp_dir);
    if($err) { die ($err); }
}

sub untgz_file : Test(1){
    my $self = shift;

    my $url = 'http://www.handle.net/hs-source/hcc5.tar.gz';
    my $filename = 'hcc5.tar.gz';
    my $expanded_dir_name = 'hcc5';
    my $md5_expected = 'fdc4c09d3d6808219eae310bc740e99c';

    my $temp_dir = mkdtemp("/tmp/feed_test_XXXXX");

    eval {
        HTFeed::Stage::Download::download(get_fake_stage(), url => $url, path => $temp_dir, filename => $filename);
        HTFeed::Stage::Unpack::untgz_file(get_fake_stage(), "$temp_dir/$filename", $temp_dir );
        unlink "$temp_dir/$filename";
        
        my $md5_found = md5_dir("$temp_dir/$expanded_dir_name");
       
        is ($md5_found, $md5_expected);
    };

    # catch exception, clean up & rethrow
    my $err = $@;

    remove_tree($temp_dir);

    if($err) { die ($err); }
}

1;

__END__
