package HTFeed::Storage;

use strict;
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use File::Path qw(make_path);
use File::Pairtree qw(id2ppath s2ppchars);
use HTFeed::VolumeValidator;
use URI::Escape;

sub new {
  my $class = shift;

  my %args = @_;

  die("Missing required arguments 'volume' and/or 'collate'")
    unless $args{volume} and $args{collate};

  my $volume = $args{volume};


  my $self = {
    volume => $volume,
    collate => $args{collate},
    namespace => $volume->get_namespace(),
    objid => $volume->get_objid(),
  };

  bless($self, $class);
  return $self;
}

sub make_object_path {
  my $self = shift;

  if(! -d $self->object_path) {
    $self->safe_make_path($self->object_path);
  }
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

sub object_path {
  my $self = shift;
  my $config_key = shift;

  return sprintf('%s/%s/%s%s',
    get_config('repository'=>$config_key),
    $self->{namespace},
    id2ppath($self->{objid}),
    s2ppchars($self->{objid}));
}

sub stage_path {
  my $self = shift;
  my $config_key = shift;

  return sprintf('%s/%s.%s',
    get_config('repository'=>$config_key),
    $self->{namespace},
    s2ppchars($self->{objid}));
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

    $self->{collate}->_set_done();
    return $self->{collate}->succeeded();
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

sub validate {
  my $self = shift;

  my $volume = $self->{volume};
  my $stage_path = $self->stage_path;
  my $mets_stage = $volume->get_mets_path($stage_path);
  my $zip_stage = $volume->get_zip_path($stage_path);

  # might not be in repo...
  my $mets = $volume->_parse_xpc($mets_stage);
  my $zipname = $volume->get_zip_filename();;

  my $mets_zipsum = $mets->findvalue(
    "//mets:file[mets:FLocat/\@xlink:href='$zipname']/\@CHECKSUM");

  if(not defined $mets_zipsum or length($mets_zipsum) ne 32) {
    # zip name may be uri-escaped in some cases
    $zipname = uri_escape($zipname);
    $mets_zipsum = $mets->findvalue(
      "//mets:file[mets:FLocat/\@xlink:href='$zipname']/\@CHECKSUM");
  }

  if ( not defined $mets_zipsum or length($mets_zipsum) ne 32 ) {
    $self->set_error('MissingValue',
      file => $mets_stage,
      field => 'checksum',
      detail => "Couldn't locate checksum for zip $zipname in METS $mets_stage");
    return;
  }

  my $realsum = HTFeed::VolumeValidator::md5sum(
    $zip_stage );

  unless ( $mets_zipsum eq $realsum ) {
    $self->set_error(
      "BadChecksum",
      field    => 'checksum',
      file     => $zip_stage,
      expected => $mets_zipsum,
      actual   => $realsum
    );
    return;
  }

  return 1;
}

sub set_error {
  my $self = shift;

  $self->{collate}->set_error(@_);
}

sub zip_size {
  my $self = shift;
  my $volume = $self->{volume};

  my $size = -s $volume->get_zip_path($self->object_path());

  die("Can't get zip size: $!") unless defined $size;

  return $size;
}

sub mets_size {
  my $self = shift;
  my $volume = $self->{volume};

  my $size = -s $volume->get_mets_path($self->object_path());

  die("Can't get mets size: $!") unless defined $size;

  return $size;
}

1;
