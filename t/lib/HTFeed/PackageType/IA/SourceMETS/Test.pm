package HTFeed::PackageType::IA::SourceMETS::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
use HTFeed::Config qw(get_config);
use HTFeed::PackageType::IA::SourceMETS;
use File::Copy;
use File::Path qw(make_path);
use Test::More;

# Test SourceMETS with undamaged package
sub SourceMETS : Test(1){

	test_config('undamaged');


	my $self = shift;

  my $volume = $self->{volume};
  mkdir($volume->get_staging_directory());
	my $stage = HTFeed::PackageType::IA::SourceMETS->new(volume => $volume);
  $volume->record_premis_event('file_rename');
  $volume->record_premis_event('image_header_modification');
  $volume->record_premis_event('package_inspection');
  $volume->record_premis_event('source_md5_fixity');
  $volume->record_premis_event('ocr_normalize');
	ok($stage->run(), 'IA: SourceMETS succeeded with undamaged package');
}

# Test for errors with damaged package
sub Errors : Test(1){

	test_config('damaged');

    my $self = shift;
    my $stage = $self->{test_stage};
    my $volume = $self->{volume};
    my $ia_id = $volume->get_ia_id();
    my $objdir = $volume->get_download_directory();
    my $scandata = "$objdir/${ia_id}_scandata.xml";

    #get damaged scandata from "samples"
    my $samples = get_config('test_staging','damaged') . "/samples/ia/${ia_id}";
    my $broken_scanData = "$samples/${ia_id}_scandata.xml";
    copy($broken_scanData,$objdir) or die "copy failed: $!";

    # test stage with damaged $scandata
    eval { $stage->run() };
    ok(!$stage->succeeded, 'IA: SourceMETS stage fails on damaged package');

    #replace with standard scandata for next stage test
    my $clean_copy = get_config('test_staging','undamaged') . "/download/ia/$ia_id/${ia_id}_scandata.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";

}

sub pkgtype { 'ia' }
1;

__END__
