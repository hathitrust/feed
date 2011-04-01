package HTFeed::PackageType::IA::SourceMETS::Test;

use warnings;
use strict;
use base qw(HTFeed::Stage::AbstractTest);
use HTFeed::Test::Support qw(get_fake_stage);
use File::Path qw(make_path);
use Test::More;

sub get_scanData : Test(setup){
	# get config
}

sub SourceMETS : Test(1){
	my $self = shift;
	my $stage = $self->{test_stage};
	ok($stage->run(), 'SourceMETS ok');
}

sub Errors : Test{
	# set to damaged

	my $self = shift,
	my $volume = $self->{volume};
	my $download_dir = $volume->get_download_directory;
	my $ia_id = $volume->get_ia_id;

	#TODO trigger warning for invalid MARC XML

	# $meta_arkid ne $volume->get_objid()
	my $expected = $volume->get_objid();
	my $metaxml = $parser->parse_file("$download_directory/${ia_id}_meta.xml");
	my $meta_arkid = $metaxml->findvalue("//identifier-ark");
	ok(! $meta_arkid, $expected, 'unequal values');

	# test missing files
	my $scandata = "$download_dir/${ia_id}_scandata.xml";
	ok(! $scandata, 'missing scandata detected');

	# $eventdate doesn't match regexp'
	my $eventdate = $xpc->findvalue("//scribe:scanLog/scribe:scanEvent[1]/scribe:endTimeStamp | //scanLog/scanEvent[1]/endTimeStamp");
	unlike($eventdate =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/, 'eventDate mismatch') 

	# $scribe undef
    my $scribe = $xpc->findvalue("//scribe:scanLog/scribe:scanEvent[1]/scribe:scribe | //scanLog/scanEvent[1]/scribe");
	ok($scribe, undef, 'undefined scribe detected');

}
1;

__END__
