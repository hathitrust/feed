package HTFeed::Stage::Collate;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use HTFeed::DBTools;
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);

=head1 NAME

HTFeed::Stage::Collate.pm

=head1 SYNOPSIS

	Base class for Collate stage
	Establishes pairtree object path for ingest

=cut

sub run{
    my $self = shift;
    $self->{is_repeat} = 0;

    $self->link;
    $self->copy;

    return $self->succeeded();
}

sub copy {
  my $self = shift;
  my $volume = $self->{volume};
  my $mets_source = $volume->get_mets_path();
  my $zip_source = $volume->get_zip_path();

  my $object_path = $self->object_path;

  # make sure the operation will succeed
  if (-f $mets_source and -f $zip_source and -d $object_path){
    # move mets and zip to repo
    system('cp','-f',$mets_source,$object_path)
        and $self->set_error('OperationFailed', operation => 'cp', detail => "cp $mets_source $object_path failed with status: $?");

    system('cp','-f',$zip_source,$object_path)
        and $self->set_error('OperationFailed', operation => 'cp', detail => "cp $zip_source $object_path failed with status: $?");

    $volume->update_feed_audit($object_path);

    $self->_set_done();
    return $self->succeeded();
  } else {
    # report which file(s) are missing
    my $detail = 'Collate failed, file(s) not found: ';
    $detail .= $mets_source unless(-f $mets_source);
    $detail .= $zip_source  unless(-f $zip_source);
    $detail .= $object_path unless(-d $object_path);

    $self->set_error('OperationFailed', detail => $detail);
    return;
  }
}

sub object_path {
  my $self = shift;

  my $namespace = $self->{volume}->get_namespace();
  my $objid = $self->{volume}->get_objid();
  my $pt_objid = s2ppchars($objid);

  return sprintf('%s/%s/%s%s',get_config('repository'=>'obj_dir'),$namespace,id2ppath($objid),$pt_objid);
}

sub link {
  my $self = shift;
  my $volume = $self->{volume};
  my $namespace = $volume->get_namespace();
  my $objid = $volume->get_objid();
  my $pt_objid = s2ppchars($objid);
  my $object_path = $self->object_path();
  $self->{is_repeat} = 0;

  # Create link from 'link_dir' area, if needed
  # if link_dir==obj_dir we don't want to use the link_dir
  if(get_config('repository'=>'link_dir') ne get_config('repository'=>'obj_dir')) {
      my $link_parent = sprintf('%s/%s/%s',get_config('repository','link_dir'),$namespace,id2ppath($objid));
      my $link_path = $link_parent . $pt_objid;

      # this is a re-ingest if the dir already exists, log this
      if (-l $link_path){
          $self->set_info('Collating volume that is already in repo');
          $self->{is_repeat} = 1;
          # make sure we have a link
          unless ($object_path = readlink($link_path)){
              # there is no good reason we chould have a dir and no link
              $self->set_error('OperationFailed', operation => 'readlink', file => $link_path, detail => "readlink failed: $!") 
                  and return;
          }
      }
      # make dir or error and return
      else{
          # make object path
          make_path($object_path);
          # make link path
          make_path($link_parent);
          # make link
          symlink ($object_path, $link_path)
              or $self->set_error('OperationFailed', operation => 'mkdir', detail => "Could not create dir $link_path") and return;
      }
  } else{ # handle re-ingest detection and dir creation where link_dir==obj_dir
      if(-d $object_path) {
          # this is a re-ingest if the dir already exists, log this
          $self->set_info('Collating volume that is already in repo');
          $self->{is_repeat} = 1;
      } else{
          make_path($object_path)
              or $self->set_error('OperationFailed', operation => 'mkdir', detail => "Could not create dir $object_path") and return;
      }
  }
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
    $self->{volume}->clean_sip_success();
}

1;

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
