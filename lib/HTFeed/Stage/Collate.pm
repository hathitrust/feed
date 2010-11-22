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
    my $pairtree_path = sprintf('%s/%s/%s%s',get_config('repository_path'),$namespace,id2ppath($pairtree_objid),$pairtree_objid);
    my $staging_dir = get_config('staging'=>'memory');

    # this is a re-ingest if the dir already exists, log this
    if (-d $pairtree_path){
        $self->set_info('Collating volume that is already in repo');
    }
    # make dir or error and return
    else{
        make_path($pairtree_path) or $self->set_error('OperationFailed', detail => "Could not create dir $pairtree_path")
            and return;
    }

    # move mets and zip to repo    
    my $cp_source = sprintf("%s/%s.mets.xml",$staging_dir,$objid);
    my $cp_target = sprintf("%s/%s.mets.xml",$pairtree_path,$pairtree_objid);
    copy($cp_source,$cp_target)
        or $self->set_error('OperationFailed', detail => "cp $cp_source $cp_target failed: $!");
            
    $cp_source = sprintf("%s/%s.zip",$staging_dir,$objid);
    $cp_target = sprintf("%s/%s.zip",$pairtree_path,$pairtree_objid);
    copy($cp_source,$cp_target)
        or $self->set_error('OperationFailed', detail => "cp $cp_source $cp_target failed: $!");
    
    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
