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
    my $pairtree_object_path = sprintf('%s/%s/%s%s',get_config('repository'=>'destdir'),$namespace,id2ppath($pairtree_objid),$pairtree_objid);
    my $pairtree_link_parent = sprintf('%s/%s/%s',get_config('repository'=>'authdir'),$namespace,id2ppath($pairtree_objid));
    my $pairtree_link_path = $pairtree_link_parent . $pairtree_objid;
    my $staging_dir = get_config('staging'=>'memory');

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
    
    my $mets_source = sprintf("%s/%s.mets.xml",$staging_dir,$objid);
    my $mets_target = sprintf("%s/%s.mets.xml",$pairtree_object_path,$pairtree_objid);
    my $zip_source = sprintf("%s/%s.zip",$staging_dir,$objid);
    my $zip_target = sprintf("%s/%s.zip",$pairtree_object_path,$pairtree_objid);

    # make sure the operation will succeed
    if (-f $mets_source and -f $zip_source){
        # move mets and zip to repo
        copy($mets_source,$mets_target)
            or $self->set_error('OperationFailed', detail => "cp $mets_source $mets_target failed: $!");
            
        copy($zip_source,$zip_target)
            or $self->set_error('OperationFailed', detail => "cp $zip_source $zip_target failed: $!");

        $self->_set_done();
        return $self->succeeded();
    }
    
    $self->set_error('OperationFailed', detail => 'Collate failed, file not found');
    return;
}

sub clean_always{
    my $self = shift;
    $self->clean_mets();
    $self->clean_packed_object();
}

1;

__END__
