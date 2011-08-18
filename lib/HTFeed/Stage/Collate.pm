package HTFeed::Stage::Collate;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use HTFeed::DBTools;
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my $pairtree_objid = s2ppchars($objid);
    my $pairtree_object_path = sprintf('%s/%s/%s%s',get_config('repository'=>'obj_dir'),$namespace,id2ppath($objid),$pairtree_objid);
    $self->{is_repeat} = 0;

    # Create link from 'link_dir' area, if needed
    # if link_dir==obj_dir we don't want to use the link_dir
    if(get_config('repository'=>'link_dir') ne get_config('repository'=>'obj_dir')) {
        my $pairtree_link_parent = sprintf('%s/%s/%s',get_config('repository','link_dir'),$namespace,id2ppath($objid));
        my $pairtree_link_path = $pairtree_link_parent . $pairtree_objid;

        # this is a re-ingest if the dir already exists, log this
        if (-l $pairtree_link_path){
            $self->set_info('Collating volume that is already in repo');
            $self->{is_repeat} = 1;
            # make sure we have a link
            unless ($pairtree_object_path = readlink($pairtree_link_path)){
                # there is no good reason we chould have a dir and no link
                $self->set_error('OperationFailed', operation => 'readlink', file => $pairtree_link_path, detail => "readlink failed: $!") 
                    and return;
            }
        }
        # make dir or error and return
        else{
            # make object path
            make_path($pairtree_object_path);
            # make link path
            make_path($pairtree_link_parent);
            # make link
            symlink ($pairtree_object_path, $pairtree_link_path)
                or $self->set_error('OperationFailed', operation => 'mkdir', detail => "Could not create dir $pairtree_link_path") and return;
        }
    } else{ # handle re-ingest detection and dir creation where link_dir==obj_dir
        if(-d $pairtree_object_path) {
            # this is a re-ingest if the dir already exists, log this
            $self->set_info('Collating volume that is already in repo');
            $self->{is_repeat} = 1;
        } else{
            make_path($pairtree_object_path)
                or $self->set_error('OperationFailed', operation => 'mkdir', detail => "Could not create dir $pairtree_object_path") and return;
        }
    }

    my $mets_source = $volume->get_mets_path();
    my $zip_source = $volume->get_zip_path();

    # make sure the operation will succeed
    if (-f $mets_source and -f $zip_source and -d $pairtree_object_path){
        # move mets and zip to repo
        system('cp','-f',$mets_source,$pairtree_object_path)
            and $self->set_error('OperationFailed', operation => 'cp', detail => "cp $mets_source $pairtree_object_path failed with status: $?");
            
        system('cp','-f',$zip_source,$pairtree_object_path)
            and $self->set_error('OperationFailed', operation => 'cp', detail => "cp $zip_source $pairtree_object_path failed with status: $?");

        $self->_set_done();
        return $self->succeeded();
    }
    
    # report which file(s) are missing
    my $detail = 'Collate failed, file(s) not found: ';
    $detail .= $mets_source unless(-f $mets_source);
    $detail .= $zip_source  unless(-f $zip_source);
    $detail .= $pairtree_object_path unless(-d $pairtree_object_path);
    
    $self->set_error('OperationFailed', detail => $detail);
    return;
}

sub success_info {
    my $self = shift;
    return "repeat=" . $self->{is_repeat};
}

sub stage_info{
    return {success_state => 'collated', failure_state => 'punted'};
}

sub clean_always{
    my $self = shift;
    $self->{volume}->clean_mets();
    $self->{volume}->clean_zip();
}

sub clean_success {
    my $self = shift;
    $self->{volume}->clear_premis_events();
    $self->{volume}->clean_download();
}

1;

__END__
