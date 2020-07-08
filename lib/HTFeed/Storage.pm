package HTFeed::Storage;

use strict;
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use File::Path qw(make_path remove_tree);
use File::Pairtree qw(id2ppath s2ppchars);
use HTFeed::VolumeValidator;
use URI::Escape;
use List::MoreUtils qw(uniq);

sub new {
  my $class = shift;

  my %args = @_;

  die("Missing required argument 'volume'")
    unless $args{volume};

  my $volume = $args{volume};


  my $self = {
    volume => $volume,
    namespace => $volume->get_namespace(),
    objid => $volume->get_objid(),
    errors => [],
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
  get_logger()->trace("copying METS from: $mets_source");
  my $zip_source = $volume->get_zip_path();
  get_logger()->trace("copying ZIP from: $mets_source");

  my $stage_path = $self->stage_path;
  get_logger()->trace("staging to: $stage_path");
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

sub stage_path_from_base {
  my $self = shift;
  my $base = shift;

  return sprintf('%s/.tmp/%s.%s',
    $base,
    $self->{namespace},
    s2ppchars($self->{objid}));
};

sub stage_path {
  my $self = shift;
  my $config_key = shift;

  return $self->stage_path_from_base(get_config('repository' => $config_key));
}

sub move {
  my $self = shift;
  my $volume = $self->{volume};
  my $mets_stage = $self->mets_stage_path;
  my $zip_stage = $self->zip_stage_path;

  my $object_path = $self->object_path;

  # make sure the operation will succeed
  if (-f $mets_stage and -f $zip_stage and -d $object_path){
    $self->safe_system('mv','-f',$mets_stage,$object_path);
    $self->safe_system('mv','-f',$zip_stage,$object_path);

    return 1;
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

sub clean_staging {
  my $self = shift;
  my $stage_path = $self->stage_path;

  get_logger->trace("Cleaning up $stage_path");
  remove_tree($stage_path);
};

sub cleanup {
  #noop
}

sub rollback {
  #noop
}

sub record_audit {
  #noop
}

sub postvalidate {
  my $self = shift;

  $self->validate_mets($self->object_path) &&
  $self->validate_zip($self->object_path);
}

sub prevalidate {
  my $self = shift;

  $self->validate_mets($self->stage_path) &&
  $self->validate_zip($self->stage_path) &&
  $self->validate_zip_contents($self->stage_path);
}

# TODO move this to pack
sub validate_zip_contents {
  my $self = shift;
  my $path = shift;

  my $volume = $self->{volume};
  my $pt_objid = $volume->get_pt_objid();

  my $zip_stage = get_config('staging'=>'zip') . "/$pt_objid";

  my $mets_path = $volume->get_mets_path($path);
  my $zip_path = $volume->get_zip_path($path);
  HTFeed::Stage::Unpack::unzip_file($self,$zip_path,$zip_stage);
  my $checksums = $volume->get_checksum_mets($mets_path);
  my $files = $volume->get_all_directory_files($zip_stage);
  return $self->validate_zip_checksums($checksums,$files,$zip_stage);
  #
}

sub validate_mets {
  my $self = shift;
  my $volume = $self->{volume};
  my $path = shift;
  my $mets_path = $volume->get_mets_path($path);
  my $orig_mets_path = $volume->get_mets_path();

  my $mets_checksum = HTFeed::VolumeValidator::md5sum($mets_path);
  my $orig_mets_checksum = HTFeed::VolumeValidator::md5sum($orig_mets_path);

  unless ( $mets_checksum eq $orig_mets_checksum ) {
    $self->set_error(
      "BadChecksum",
      field    => 'checksum',
      file     => $mets_path,
      expected => $orig_mets_checksum,
      actual   => $mets_checksum
    );
    return;
  }

  return 1;
}

sub validate_zip {
  my $self = shift;

  my $volume = $self->{volume};
  my $path = shift;
  my $mets_path = $volume->get_mets_path($path);
  my $zip_path = $volume->get_zip_path($path);

  my $mets = $volume->_parse_xpc($mets_path);
  my $zipname = $volume->get_zip_filename();

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
      file => $mets_path,
      field => 'checksum',
      detail => "Couldn't locate checksum for zip $zipname in METS $mets_path");
    return;
  }

  my $realsum = HTFeed::VolumeValidator::md5sum(
    $zip_path );

  unless ( $mets_zipsum eq $realsum ) {
    $self->set_error(
      "BadChecksum",
      field    => 'checksum',
      file     => $zip_path,
      expected => $mets_zipsum,
      actual   => $realsum
    );
    return;
  }

  return 1;
}

sub set_error {
  my $self = shift;
  my $error = shift;

  # log error w/ l4p
  my $logger = get_logger( ref($self) );
  $logger->error(
      $error,
      namespace => $self->{volume}->get_namespace(),
      objid     => $self->{volume}->get_objid(),
      stage     => ref($self),
      @_
  );

  push(@{$self->{errors}},[$error,@_]);
}

sub zip_obj_path {
  my $self = shift;
  $self->{volume}->get_zip_path($self->object_path());
}

sub mets_obj_path {
  my $self = shift;
  $self->{volume}->get_mets_path($self->object_path());
}

sub zip_stage_path {
  my $self = shift;
  $self->{volume}->get_zip_path($self->stage_path());
}

sub mets_stage_path {
  my $self = shift;
  $self->{volume}->get_mets_path($self->stage_path());
}

sub zip_size {
  my $self = shift;
  my $volume = $self->{volume};

  my $size = -s $self->zip_obj_path;

  die("Can't get zip size: $!") unless defined $size;

  return $size;
}

sub mets_size {
  my $self = shift;
  my $volume = $self->{volume};

  my $size = -s $self->mets_obj_path;

  die("Can't get mets size: $!") unless defined $size;

  return $size;
}

sub validate_zip_checksums {
  my $self             = shift;
  my $checksums        = shift;
  my $files = shift;
  my $path             = shift;

  # make sure we check every file in the directory except for the checksum file
  # and make sure we check every file in the checksum file

  my @tovalidate = uniq( sort( map { lc($_) } @$files, map { lc($_) } keys(%$checksums) ));

  my @bad_files = ();

  my $ok = 1;

  foreach my $file (@tovalidate) {
    next if $file =~ /.zip$/;
    my $expected = $checksums->{$file};
    if ( not defined $expected ) {
      $ok = 0;
      $self->set_error(
        "BadChecksum",
        field  => 'checksum',
        file   => $file,
        detail => "File present in zip but not in METS"
      );
    }
    elsif ( !-e "$path/$file" ) {
      $ok = 0;
      $self->set_error(
        "MissingFile",
        file => $file,
        detail =>
        "File listed in METS but not present in zip"
      );
    }
    elsif ( ( my $actual = HTFeed::VolumeValidator::md5sum("$path/$file") ) ne $expected ) {
      $ok = 0;
      $self->set_error(
        "BadChecksum",
        field    => 'checksum',
        file     => $file,
        expected => $expected,
        actual   => $actual
      );
      push( @bad_files, "$file" );
    }

  }

  return $ok;

}

1;
