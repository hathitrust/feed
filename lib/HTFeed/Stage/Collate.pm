package HTFeed::Stage::Collate;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use File::Path qw(make_path);
use File::Copy;
use File::Pairtree;

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my $pairtree_objid = s2ppchars($objid);
    my $pairtree_object_path = sprintf('%s/%s/%s%s',get_config('repository'=>'destdir'),$namespace,id2ppath($objid),$pairtree_objid);

    # Create link from 'authdir' area, if needed

    if(get_config('repository'=>'use_authdir') == 1) {
	my $pairtree_link_parent = sprintf('%s/%s/%s',get_config('repository','authdir'),$namespace,id2ppath($objid));
	my $pairtree_link_path = $pairtree_link_parent . $pairtree_objid;

	# this is a re-ingest if the dir already exists, log this
	if (-d $pairtree_link_parent){
	    $self->set_info('Collating volume that is already in repo');
	    # make sure we have a link
	    unless (-l $pairtree_link_path){
		$self->set_error('OperationFailed', detail => "link $pairtree_link_path missing, cannot reingest")
		    and return;
	    }
	}
	# make dir or error and return
	else{
	    # make object path
	    make_path($pairtree_object_path)
		or $self->set_error('OperationFailed', detail => "Could not create dir $pairtree_object_path") and return;
	    # make link path
	    make_path($pairtree_link_parent)
		or $self->set_error('OperationFailed', detail => "Could not create dir $pairtree_link_path") and return;
	    # make link
	    symlink ($pairtree_object_path, $pairtree_link_path)
		or $self->set_error('OperationFailed', detail => "Could not create dir $pairtree_link_path") and return;
	}
    } elsif(! -d $pairtree_object_path) {
	make_path($pairtree_object_path)
	    or $self->set_error('OperationFailed', detail => "Could not create dir $pairtree_object_path") and return;
    }
    
    my $staging_dir = get_config('staging'=>'memory');
    my $mets_source = $volume->get_mets_path();
    my $zip_source = $volume->get_zip_path();

    # make sure the operation will succeed
    if (-f $mets_source and -f $zip_source and -d $pairtree_object_path){
        # move mets and zip to repo
        copy($mets_source,$pairtree_object_path)
            or $self->set_error('OperationFailed', detail => "cp $mets_source $pairtree_object_path failed: $!");
            
        copy($zip_source,$pairtree_object_path)
            or $self->set_error('OperationFailed', detail => "cp $zip_source $pairtree_object_path failed: $!");

        $self->_set_done();
        return $self->succeeded();
    }
    
    $self->set_error('OperationFailed', detail => 'Collate failed, file not found');
    return;
}

sub stage_info{
    return {success_state => 'collated', failure_state => 'punted'};
}

sub clean_always{
    my $self = shift;
    $self->clean_mets();
    $self->clean_zip();
}

1;

__END__
