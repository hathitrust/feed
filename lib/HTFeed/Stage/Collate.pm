package HTFeed::Stage::Collate;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use HTFeed::DBTools;
use Log::Log4perl qw(get_logger);
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

    $self->stage;
    $self->validate;
    $self->link;
    $self->move;

    return $self->succeeded();
}

sub stage {
  my $self = shift;
  my $volume = $self->{volume};
  my $mets_source = $volume->get_mets_path();
  my $zip_source = $volume->get_zip_path();

  my $stage_path = $self->stage_path;
  my $err;

  $self->safe_make_path($stage_path);

  # make sure the operation will succeed
  if (-f $mets_source and -f $zip_source and -d $stage_path){
    $self->safe_system('cp','-f',$mets_source,$stage_path);
    $self->safe_system('cp','-f',$zip_source,$stage_path);

    return 1;

  } else {
    # report which file(s) are missing
    my $detail = 'Collate failed, file(s) not found: ';
    $detail .= $mets_source unless(-f $mets_source);
    $detail .= $zip_source  unless(-f $zip_source);
    $detail .= $stage_path unless(-d $stage_path);

    $self->set_error('OperationFailed', detail => $detail);
    return;
  }
}

sub validate {
  return 1;
}

sub move {
  my $self = shift;
  my $volume = $self->{volume};
  my $stage_path = $self->stage_path;
  my $mets_stage = $volume->get_mets_path($stage_path);
  my $zip_stage = $volume->get_zip_path($stage_path);

  my $object_path = $self->object_path;

  # make sure the operation will succeed
  if (-f $mets_stage and -f $zip_stage and -d $object_path){
    $self->safe_system('mv','-f',$mets_stage,$object_path);
    $self->safe_system('mv','-f',$zip_stage,$object_path);

    get_logger->trace("Cleaning up $stage_path");
    system('rmdir',$stage_path)
        and get_logger()->warn("Can't rmdir $stage_path: $!");

    $volume->update_feed_audit($object_path);

    $self->_set_done();
    return $self->succeeded();
  } else {
    # report which file(s) are missing
    my $detail = 'Collate failed, file(s) not found: ';
    $detail .= $mets_stage unless(-f $mets_stage);
    $detail .= $zip_stage  unless(-f $zip_stage);
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

sub stage_path {
  my $self = shift;

  my $namespace = $self->{volume}->get_namespace();
  my $objid = $self->{volume}->get_objid();

  return sprintf('%s/%s.%s',get_config('repository'=>'obj_stage_dir'),$namespace,s2ppchars($objid))
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
    $self->symlink_if_needed;
  } elsif(-d $object_path) {
    # handle re-ingest detection and dir creation where link_dir==obj_dir
    $self->set_info('Collating volume that is already in repo');
    $self->{is_repeat} = 1;
  } else{
    $self->safe_make_path($object_path);
  }

  return 1;
}

sub safe_system {
  my $self = shift;
  my @args = @_;
  my $printable_args = '"' . join(' ',@args) . '"';

  get_logger->trace("Running command $printable_args");

  if ( system(@args) ) {
    $self->set_error('OperationFailed',
      operation => $args[0],
      detail => "Command $printable_args failed: $!");
    return;
  } else {
    return 1;
  }
}

sub safe_make_path {
  my $self = shift;
  my $path = shift;

  get_logger->trace("Making path $path");

  if( make_path($path) ) {
    return 1;
  } else {
    $self->set_error('OperationFailed',
      operation => 'mkdir',
      detail => "Could not create dir $path: $!");
    return;
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

sub check_existing_link {
  my $self = shift;
  my $object_path = shift;
  my $link_path = shift;

  $self->set_info('Collating volume that is already in repo');
  $self->{is_repeat} = 1;
  # make sure we have a link
  unless ($object_path = readlink($link_path)){
    # there is no good reason we chould have a dir and no link
    $self->set_error('OperationFailed', operation => 'readlink', file => $link_path, detail => "readlink failed: $!")
  }
}

sub make_link {
  my $self = shift;
  my $object_path = shift;
  my $link_path = shift;

  get_logger->trace("Symlinking $object_path to $link_path");
  symlink ($object_path, $link_path)
    or $self->set_error('OperationFailed', operation => 'symlink', detail => "Could not symlink $object_path to $link_path $!");
}

sub symlink_if_needed {
  my $self = shift;

  my $volume = $self->{volume};
  my $namespace = $volume->get_namespace();
  my $objid = $volume->get_objid();
  my $pt_objid = s2ppchars($objid);
  my $object_path = $self->object_path();
  $self->{is_repeat} = 0;

  my $link_parent = sprintf('%s/%s/%s',get_config('repository','link_dir'),$namespace,id2ppath($objid));
  my $link_path = $link_parent . $pt_objid;

  if (-l $link_path){
    # this is a re-ingest if the dir already exists, log this
    $self->check_existing_link($object_path,$link_path);
  }
  else{
    $self->safe_make_path($object_path);
    $self->safe_make_path($link_parent);
    $self->make_link($object_path,$link_path);
  }

  return 1;
}

1;

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
