package HTFeed::PackageType::IA::OCRSplit::Test;

use warnings;
use strict;
use base qw(HTFeed::PackageType::IA::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use HTFeed::Config qw(set_config);
use File::Copy;
use File::Path qw(make_path);
use Test::More;

my $damaged = "/htapps/test.babel/feed/t/staging/DAMAGED";
my $undamaged = "/htapps/test.babel/feed/t/staging/UNDAMAGED";

sub OCRSplit : Test(2){
	set_config("$undamaged/download","staging"=>"download");
    my $self = shift;
	my $stage = $self->{test_stage};	
	ok($stage->run(), 'OCRSplit succeeded');
	ok($stage->stage_info(), 'stage info ok');
}

sub Errors : Test(2){

	#load damaged package
	set_config($damaged,"staging"=>"download");
	my $self = shift;
	my $stage = $self->{test_stage};
	my $volume = $self->{volume};
	my $objdir = $volume->get_download_directory();

	my $ia_id = $volume->get_ia_id();
	my $xml = "$objdir/${ia_id}_djvu.xml";

	unlink($xml);
	ok(! -e $xml, 'missing djvu detected');
	ok(! $stage->run(), '...and the stage fails');

	my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_djvu.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";
}

sub usemap : Test(1){
	set_config($damaged,"staging"=>"download");
    my $self = shift;
    my $stage = $self->{test_stage};
    my $volume = $self->{volume};
    my $objdir = $volume->get_download_directory();
	my $ia_id =  $volume->get_ia_id();

	#get broken djvu from samples
    my $samples = "$damaged/samples/ia/${ia_id}";
    my $broken_scanData = "$samples/${ia_id}_djvu.xml";
    copy($broken_scanData,$objdir) or die "copy failed: $!";

    #run the whole thing and see coverage
    ok($stage->run(), 'pass with warnings');

    #replace with standard djvu for next stage test
    my $clean_copy = "$undamaged/download/ia/$ia_id/${ia_id}_djvu.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";

}

1;

__END__
