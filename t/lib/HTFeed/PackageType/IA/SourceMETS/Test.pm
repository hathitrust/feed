package HTFeed::PackageType::IA::SourceMETS::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage test_config);
#use HTFeed::Config qw(set_config);
use HTFeed::PackageType::IA::SourceMETS;
use File::Copy;
use File::Path qw(make_path);
use Test::More;

# Test SourceMETS with undamaged package
sub SourceMETS : Test(1){

	test_config('undamaged');


	my $self = shift;
	my $stage = $self->{test_stage};

  $self->set_bibdata;
  my $volume = $self->{volume};
  $volume->record_premis_event('file_rename');
  $volume->record_premis_event('image_header_modification');
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

    $self->set_bibdata;
    #get damaged scandata from "samples"
    my $samples = "/htapps/feed.babel/test_data/staging/DAMAGED/samples/ia/${ia_id}";
    my $broken_scanData = "$samples/${ia_id}_scandata.xml";
    copy($broken_scanData,$objdir) or die "copy failed: $!";

    # test stage with damaged $scandata
    eval { $stage->run() };
    ok(!$stage->succeeded, 'IA: SourceMETS stage fails on damaged package');

    #replace with standard scandata for next stage test
    my $clean_copy = "/htapps/feed.babel/test_data/staging/UNDAMAGED/download/ia/$ia_id/${ia_id}_scandata.xml";
    copy($clean_copy,$objdir) or die "copy failed: $!";

}

sub set_bibdata {
	my $self = shift;

  my $dbh = HTFeed::DBTools::get_dbh();
  my $volume = $self->{volume};
  my $objid = $volume->get_objid();
  my $ns = $volume->get_namespace();
  $dbh->do("REPLACE INTO feed_zephir_items (namespace, id, collection, digitization_source, returned) values ('$ns','$objid','INRLF','ia','0')");
}

sub pkgtype { 'ia' }
1;

__END__
