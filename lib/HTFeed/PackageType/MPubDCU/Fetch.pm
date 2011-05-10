package HTFeed::PackageType::MPubDCU::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);

sub run {

	my $self = shift;
	my $volume = $self->{volume};
	my $objid = $volume->get_objid();
	my $packagetype = $volume->get_packagetype();
	my $ns = $volume->get_namespace();
	my $fetch_dir = get_config('staging'=>'fetch');
	my $staging_dir = get_config('staging' => 'download');
	my $source = "$fetch_dir/$packagetype/forHT/$objid";

	if(! -e $staging_dir) {
		mkdir $staging_dir or die("Can't mkdir $staging_dir: $!");
	}
	
<<<<<<< Updated upstream
	system("cp -rs $source $staging_dir") 
        and $self->set_error('OperationFailed', operation=>'copy', detail=>"copy $src $dest failed with status: $?");

	$self->_set_done();
	return $self->succeeded();
}

1;
