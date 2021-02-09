package HTFeed::Storage;

use strict;
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use File::Path qw(make_path remove_tree);
use File::Pairtree qw(id2ppath s2ppchars);
use HTFeed::VolumeValidator;
use URI::Escape;
use List::MoreUtils qw(uniq);

sub for_volume {
  my $volume = shift;
  my $config_key = shift || 'storage_classes';

  my @storages;
  foreach my $storage_config (@{get_config($config_key)}) {
    push(@storages, $storage_config->{class}->new(volume => $volume,
                                                 config => $storage_config));
  }

  return @storages;
}

sub new {
  my $class = shift;

  my %args = @_;

  die("Missing required argument 'volume'")
    unless $args{volume};

  die("Missing required argument 'config'")
    unless $args{config};


  my $volume = $args{volume};
  my $config = $args{config};

  my $self = {
    volume => $volume,
    namespace => $volume->get_namespace(),
    objid => $volume->get_objid(),
    errors => [],
    config => $config,
    zip_suffix => "",
    did_encryption => 0,
  };

  bless($self, $class);
  return $self;
}

sub encrypt {
  my $self = shift;

  my $key = $self->{config}{encryption_key};

  return 1 unless $key;

  my $original = $self->zip_source();
  my $encrypted = "$original.gpg";

  my $cmd = "cat \"$key\" | gpg --quiet --passphrase-fd 0 --batch --no-tty --output '$encrypted' --symmetric '$original'";

  $self->safe_system($cmd);

  $self->{zip_suffix} = ".gpg";
  $self->{did_encryption} = 1;

  return ! $?;

}

sub verify_crypt {
  my $self = shift;
  my $volume = $self->{volume};
  my $encrypted = $self->zip_source();

  my $key = $self->{config}{encryption_key};
  return 1 unless $key;

  my $actual_checksum = $self->crypted_md5sum($encrypted,$key);

  return $self->validate_zip_checksum($volume->get_mets_path(), "gpg --decrypt '$encrypted'", $actual_checksum);
}

sub crypted_md5sum {
  my $self = shift;
  my $encrypted = shift;
  my $key = shift;

  my $cmd = "cat \"$key\" | gpg --quiet --passphrase-fd 0 --batch --no-tty --decrypt '$encrypted' | md5sum | cut -f 1 -d ' '";
  get_logger()->trace("Running $cmd");

  my $actual_checksum = `$cmd`;
  chomp($actual_checksum);

  return $actual_checksum;
}

sub make_object_path {
  my $self = shift;

  if(! -d $self->object_path) {
    $self->safe_make_path($self->object_path);
  }
}

sub zip_source {
  my $self = shift;
  my $volume = $self->{volume};

  return $volume->get_zip_path() . $self->{zip_suffix};

}

sub stage {
  my $self = shift;
  my $volume = $self->{volume};
  my $mets_source = $volume->get_mets_path();
  get_logger()->trace("copying METS from: $mets_source");
  my $zip_source = $self->zip_source();
  get_logger()->trace("copying ZIP from: $zip_source");

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
    $self->{config}->{$config_key},
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

  return $self->stage_path_from_base($self->{config}->{$config_key});
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
  my $self = shift;

  return unless $self->{did_encryption};

  $self->safe_system('rm','-f',$self->zip_source);

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

sub validate_zip_completeness {
  my $self = shift;

  my $volume = $self->{volume};
  my $pt_objid = $volume->get_pt_objid();

  my $zip_stage = get_config('staging'=>'zip') . "/$pt_objid";

  my $mets_path = $volume->get_mets_path();
  my $zip_path = $volume->get_zip_path();
  HTFeed::Stage::Unpack::unzip_file($self,$zip_path,$zip_stage);
  my $checksums = $volume->get_checksum_mets($mets_path);
  my $files = $volume->get_all_directory_files($zip_stage);
  my $ok = $self->validate_zip_checksums($checksums,$files,$zip_stage);

  remove_tree($zip_stage);

  return $ok;
}

sub prevalidate {
  my $self = shift;

  $self->validate_mets($self->stage_path) &&
  $self->validate_zip($self->stage_path)
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

sub validate_zip_checksum {
  my $self = shift;
  my $mets_path = shift;
  my $zip_path = shift;
  my $actual_checksum = shift;
  my $volume = $self->{volume};

  my $mets = $volume->_parse_xpc($mets_path);
  my $zipname = $volume->get_zip_filename();

  my $mets_zip_checksum = $mets->findvalue(
    "//mets:file[mets:FLocat/\@xlink:href='$zipname']/\@CHECKSUM");

  if(not defined $mets_zip_checksum or length($mets_zip_checksum) ne 32) {
    # zip name may be uri-escaped in some cases
    $zipname = uri_escape($zipname);
    $mets_zip_checksum = $mets->findvalue(
      "//mets:file[mets:FLocat/\@xlink:href='$zipname']/\@CHECKSUM");
  }

  if ( not defined $mets_zip_checksum or length($mets_zip_checksum) ne 32 ) {
    $self->set_error('MissingValue',
      file => $mets_path,
      field => 'checksum',
      detail => "Couldn't locate checksum for zip $zipname in METS $mets_path");
    return;
  }

  unless ( $mets_zip_checksum eq $actual_checksum ) {
    $self->set_error(
      "BadChecksum",
      field    => 'checksum',
      file     => $zip_path,
      expected => $mets_zip_checksum,
      actual   => $actual_checksum
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
  my $zip_path = $volume->get_zip_path($path) . $self->{zip_suffix};

  my $actual_checksum;
  if($self->{did_encryption}) {
    $actual_checksum = $self->crypted_md5sum($zip_path,$self->{config}{encryption_key});
  } else {
    my $zip_path = $volume->get_zip_path($path) . $self->{zip_suffix};
    $actual_checksum = HTFeed::VolumeValidator::md5sum($zip_path);
  }

  return $self->validate_zip_checksum($mets_path,$zip_path,$actual_checksum);
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
  $self->{volume}->get_zip_path($self->object_path()) . $self->{zip_suffix};
}

sub mets_obj_path {
  my $self = shift;
  $self->{volume}->get_mets_path($self->object_path());
}

sub zip_stage_path {
  my $self = shift;
  $self->{volume}->get_zip_path($self->stage_path()) . $self->{zip_suffix};
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

  @$files = map { lc($_) } @$files;
  %$checksums = map { lc($_) } %$checksums;

  my @tovalidate = uniq( sort( @$files, keys(%$checksums) ));

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

sub zip_suffix {
  my $self = shift;
  return '.zip' . $self->{zip_suffix};
}

1;
