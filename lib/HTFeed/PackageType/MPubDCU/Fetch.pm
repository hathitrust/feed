package HTFeed::PackageType::MPubDCU::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage);
use File::Copy::Recursive qw(dircopy);
use HTFeed::Config qw(get_config);

sub run {

	my $self = shift;
	my $volume = $self->{volume};
	my $objid = $volume->get_objid();
	my $packagetype = $volume->get_packagetype();
	my $ns = $volume->get_namespace();
	my $fetch_path = get_config('staging'=>'fetch') . "/$packagetype/forHT";
	my $staging_dir = get_config('staging' => 'download');

	if(! -e $staging_dir) {
		mkdir $staging_dir or die("Can't mkdir $staging_dir: $!");
	}
	
	my $src = "$fetch_path/$objid";
	my $dest = "$staging_dir/$objid";
	dircopy($src,$dest)
		or $self->set_error('OperationFailed', operation=>'copy', detail=>"copy $src $dest failed: $!");

	$self->_set_done();
	return $self->succeeded();
}

1;
