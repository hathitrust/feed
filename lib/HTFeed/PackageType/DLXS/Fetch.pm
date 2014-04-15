package HTFeed::PackageType::DLXS::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage::Fetch);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use File::Find;

sub run {
	my $self = shift;
    $self->SUPER::run();


	my $volume = $self->{volume};
	my $packagetype = $volume->get_packagetype();
	my $objid = $volume->get_objid();

	my $fetch_base = get_config('staging'=>'fetch');

	my $source = undef;

	my $base="$fetch_base/quod_obj";
    my $path_prefix = '';

    if(-e "$fetch_base/quod2ht/fixed/$objid") {
        $source = "$fetch_base/quod2ht/fixed/$objid";
    }
	elsif(-e "$base/$objid") {
        $source = "$base/$objid" 
    } else {
        $path_prefix = join('/',(split('',$objid))[0..2]);
        $source = "$base/$path_prefix/$objid" if -e "$base/$path_prefix/$objid";
    }
    
    if(not defined $source) {
        $self->set_error("MissingFile",file => "$base/$path_prefix/$objid", detail=>"Can't fetch $objid from $fetch_base");
        return;
    }

	my $dest = $volume->get_preingest_directory();

	$self->fetch_from_source($source,$dest);
	$self->fix_line_endings($dest);

	$self->_set_done();
	return $self->succeeded();
}

1;
