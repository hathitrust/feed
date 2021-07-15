package HTFeed::Storage;

use strict;
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use File::Path qw(make_path remove_tree);
use File::Pairtree qw(id2ppath s2ppchars);
use HTFeed::VolumeValidator;
use HTFeed::StorageZipAudit;
use URI::Escape;
use List::MoreUtils qw(uniq);

sub for_volume {
  my $volume = shift;
  my $config_key = shift || 'storage_classes';

  my @storages;
  my $config = get_config($config_key);
  unless (ref($config) eq 'HASH') {
    die 'Config is not a HASH ref';
  }

  foreach my $storage_name (keys %$config) {
    my $storage_config = $config->{$storage_name};
    push(@storages, $storage_config->{class}->new(volume => $volume,
                                                  config => $storage_config,
                                                  name   => $storage_name));
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

  die("Missing required argument 'name'")
    unless $args{name};

  my $volume = $args{volume};
  my $config = $args{config};
  my $name = $args{name};
  my $timestamp = $args{timestamp};

  my $self = {
    volume => $volume,
    namespace => $volume->get_namespace(),
    objid => $volume->get_objid(),
    errors => [],
    mets_source => $volume->get_mets_path(),
    zip_source => $volume->get_zip_path(),
    config => $config,
    did_encryption => 0,
    name => $name,
    timestamp => $timestamp
  };

  bless($self, $class);
  return $self;
}

# Class method
sub zip_audit_class {
  my $class = shift;

  return 'HTFeed::StorageZipAudit';
}

sub delete_objects {
  die('delete_objects is unimplemented for this storage class');
}

sub zip_source {
  my $self = shift;

  return $self->{zip_source};
}

# Temporary location for constructing the encrypted zip file prior to copying
# it to the storage staging area
sub encrypted_zip_staging {
  my $self = shift;

  return $self->{volume}->get_zip_path(get_config('staging','zipfile')) . '.gpg';
}

sub encrypt {
  my $self = shift;

  get_logger->debug("  starting encrypt");

  my $key = $self->{config}{encryption_key};

  return 1 unless $key;

  my $original = $self->{zip_source};
  my $encrypted = $self->encrypted_zip_staging;

  my $cmd = "cat \"$key\" | gpg --quiet --passphrase-fd 0 --batch --no-tty --output '$encrypted' --symmetric '$original'";
  my $success = ! $?;

  $self->safe_system($cmd);

  $self->{zip_source} = $encrypted;
  $self->{did_encryption} = 1;
  $self->{zip_suffix} = ".gpg";
  get_logger->debug("  finished encrypt");

  return $success;

}

sub encrypted_by_default {
  my $self = shift;

  return 0;
}

# For interacting with objects already in storage,
# this sets the correct zip suffix and any other needed housekeeping.
sub set_encrypted {
  my $self = shift;
  my $flag = shift;

  if ($flag) {
    unless ($self->{config}{encryption_key}) {
      die 'cannot set encrypted without encryption_key';
    }
    $self->{did_encryption} = 1;
    $self->{zip_suffix} = '.gpg';
  } else {
    $self->{did_encryption} = 0;
    $self->{zip_suffix} = '';
  }
}

sub verify_crypt {
  my $self = shift;
  my $volume = $self->{volume};
  my $encrypted = $self->{zip_source};

  get_logger()->debug("  starting verify_crypt");
  my $key = $self->{config}{encryption_key};
  return 1 unless $key;

  my $actual_checksum = $self->crypted_md5sum($encrypted,$key);

  my $valid = $self->validate_zip_checksum($self->{mets_source}, "gpg --decrypt '$encrypted'", $actual_checksum);

  get_logger()->debug("  finished verify_crypt");

  return $valid;
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
  my $ok = 1;

  get_logger()->debug("  starting make_object_path");
  if(! -d $self->object_path) {
    $ok = $self->safe_make_path($self->object_path);
  }
  get_logger()->debug("  finished make_object_path");

  return $ok;
}

sub stage {
  my $self = shift;
  my $volume = $self->{volume};
  get_logger()->debug("  starting stage");

  my $mets_source = $self->{mets_source};
  my $zip_source = $self->{zip_source};
  get_logger()->trace("copying METS from: $mets_source");
  get_logger()->trace("copying ZIP from: $zip_source");

  my $stage_path = $self->stage_path;
  get_logger()->trace("staging to: $stage_path");
  my $err;

  $self->safe_make_path($stage_path);

  # make sure the operation will succeed
  if (-f $mets_source and -f $zip_source and -d $stage_path){
    $self->safe_system('cp','-f',$mets_source,$self->mets_stage_path);
    $self->safe_system('cp','-f',$zip_source,$self->zip_stage_path);

    get_logger()->debug("  finished stage");
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
  get_logger->debug("  starting move");

  my $mets_stage = $self->mets_stage_path;
  my $zip_stage = $self->zip_stage_path;

  my $object_path = $self->object_path;

  # make sure the operation will succeed
  if (-f $mets_stage and -f $zip_stage and -d $object_path){
    $self->safe_system('mv','-f',$mets_stage,$object_path);
    $self->safe_system('mv','-f',$zip_stage,$object_path);

    get_logger->debug("  finished move");
    return 1;
  } else {
    # report which file(s) are missing
    my $detail = 'Collate failed, file(s) not found: ';
    $detail .= $mets_stage unless(-f $mets_stage);
    $detail .= $zip_stage  unless(-f $zip_stage);
    $detail .= $object_path unless(-d $object_path);

    $self->set_error('OperationFailed', detail => $detail);
    get_logger->debug("  finished move");
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
  get_logger->trace("in storage cleanup, did_encryption: $self->{did_encryption}");

  return unless $self->{did_encryption};

  $self->safe_system('rm','-f',$self->{zip_source});

}

sub rollback {
  #noop
}

sub record_audit {
  #noop
}

sub postvalidate {
  my $self = shift;

  get_logger->debug(" starting postvalidate");

  my $valid = ($self->validate_mets($self->object_path) &&
               $self->validate_zip($self->object_path));

  get_logger->debug(" finished postvalidate");

  return $valid;
}

sub validate_zip_completeness {
  my $self = shift;

  get_logger->debug("  starting validate_zip_completeness");

  my $volume = $self->{volume};
  my $pt_objid = $volume->get_pt_objid();

  my $zip_stage = get_config('staging'=>'zip') . "/$pt_objid";

  my $mets_path = $self->{mets_source};
  my $zip_path = $self->{zip_source};
  HTFeed::Stage::Unpack::unzip_file($self,$zip_path,$zip_stage);
  my $checksums = $volume->get_checksum_mets($mets_path);
  my $files = $volume->get_all_directory_files($zip_stage);
  my $ok = $self->validate_zip_checksums($checksums,$files,$zip_stage);

  remove_tree($zip_stage);
  get_logger->debug("  finished validate_zip_completeness");

  return $ok;
}

sub prevalidate {
  my $self = shift;

  get_logger->debug("  starting prevalidate");
  my $valid = ($self->validate_mets($self->stage_path) &&
               $self->validate_zip($self->stage_path));
  get_logger->debug("  finished prevalidate");

  return $valid;
}

sub validate_mets {
  my $self = shift;
  my $volume = $self->{volume};
  my $path = shift;
  my $mets_path = $path . '/' . $self->mets_filename;
  my $orig_mets_path = $self->{mets_source};

  get_logger()->trace("Validating mets at $mets_path, orig at $orig_mets_path");

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
  # will be named with the original zip filename here, not any modified version
  # for this storage
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
  my $mets_path = $path . '/' . $self->mets_filename();
  my $zip_path = $path . '/' . $self->zip_filename;

  get_logger()->trace("Validating zip at $zip_path vs. checksum in METS $mets_path");

  my $actual_checksum;
  if($self->{did_encryption}) {
    $actual_checksum = $self->crypted_md5sum($zip_path,$self->{config}{encryption_key});
  } else {
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
  $self->object_path() . '/' . $self->zip_filename();
}

sub mets_obj_path {
  my $self = shift;
  $self->object_path() . '/' . $self->mets_filename();
}

sub zip_stage_path {
  my $self = shift;
  $self->stage_path() . '/' . $self->zip_filename();
}

sub mets_stage_path {
  my $self = shift;
  $self->stage_path() . '/' . $self->mets_filename();
}

sub mets_filename {
  my $self = shift;
  $self->{volume}->get_mets_filename();
}

sub zip_filename {
  my $self = shift;
  $self->{volume}->get_pt_objid() . $self->zip_suffix;
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

  get_logger()->trace("Validating zip checksums");
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
