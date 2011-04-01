package HTFeed::PackageType::IA::OCRSplit::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub Config : Test(setup){
	#set config
}

sub OCRSplit : Test(1){
    my $self = shift;
	my $stage = $self->{test_stage};	
	ok($stage->run(), 'OCRSplit succeeded');
}

sub Errors : Test{
	#set to damaged version

	my $self = shift;
	my $volume = $self->{volume};
	my $download_dir = $volume->get_download_directory();
	my $ia_id = $volume->get_ia_id();
	my $xml = ${ia_id}_djvu.xml

	# $djvu file missing
	ok(! "$download_dir/$xml", 'missing djvu.xml detected');

	# $usemap ne /_(\d+)\./
	unlike( $usemap =~ /_(\d+)\./, '$usemap mismatch detected');

	#TODO $outfile_txt error
	
}


1;

__END__
