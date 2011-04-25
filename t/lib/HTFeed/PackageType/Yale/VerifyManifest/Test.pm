package HTFeed::PackageType::Yale::VerifyManifest::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::Yale::AbstractTest);
use HTFeed::Config qw(set_config);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

# Test stage with undamaged packaeg
sub VerifyManifest : Test(2){

	#my $config = test_config('undamaged');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/preingest','staging'=>'preingest');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/ingest','staging'=>'ingest');
    set_config('/htapps/test.babel/feed/t/staging/UNDAMAGED/download','staging'=>'download');

    my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'Yale: VerifyManifest succeeded for undamaged package');
	ok($stage->stage_info(), 'Yale: stage info returned ok for undamaged package');
}

# Test error handling with missing manifest file
sub missing : Test(2){

	#set config to damaged package
	#my $config = test_config('damaged');
    set_config('/htapps/test.babel/feed/t/staging/DAMAGED/yale/preingest','staging'=>'preingest');

	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $objdir = $volume->get_preingest_directory();
	my $objid = $volume->get_objid();
	my $hold = "$objdir/temp";
	my $meta = "$objdir/METADATA";
	my $manifest = "${objid}_AllFilesManifest.txt";

	#remove manifest, and verify that it is missing
	move("$meta/$manifest", $hold);
	ok(! -e "$meta/$manifest", "missing file detected");

	#run the stage and fail with errors
	ok(! $stage->run(), 'and we fail with errors');

	#return manifest for future tests
	move("$hold/$manifest", $meta);
}

1;

__END__
