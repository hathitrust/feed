package HTFeed::Storage::ObjectStore;

use Carp;
use Log::Log4perl qw(get_logger);
use HTFeed::Storage;
use File::Pairtree qw(id2ppath s2ppchars);
use POSIX qw(strftime);
use HTFeed::Storage::S3;
use MIME::Base64 qw(decode_base64);

use base qw(HTFeed::Storage);
use strict;

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(
      @_,
  );

	$self->{s3} ||= HTFeed::Storage::S3->new(
    bucket => $self->{config}{bucket},
    awscli => $self->{config}{awscli}
  );

  $self->{checksums} = {};

  return $self;
}

sub delete_objects {
  my $self = shift;

  my $mets = $self->mets_key;
  my $zip = $self->zip_key;
  get_logger->trace("deleting $mets and $zip");
  eval {
    $self->{s3}->rm('/' . $mets);
    $self->{s3}->rm('/' . $zip);
  };
  if ($@) {
    $self->set_error('OperationFailed',
                     detail => "delete_objects failed: $@");
    return;
  }
  return 1;
}

sub object_path {
  my $self = shift;

  $self->{timestamp} ||= strftime("%Y%m%d%H%M%S",gmtime);

  return join(".",
    $self->{namespace},
    s2ppchars($self->{objid}),
    $self->{timestamp});
}

sub clean_staging {
  # No staging path, so nothing to clean
}

sub stage_path {
  die("Not implemented for ObjectStore");
}

sub stage {
  return 1;
}

sub prevalidate {
  return 1;
}

sub make_object_path {
  return 1;
}

sub zip_key {
  my $self = shift;

  return $self->object_path . $self->zip_suffix;
}

sub mets_key {
  my $self = shift;

  return $self->object_path . ".mets.xml";
}

sub postvalidate {
  my $self = shift;

  get_logger->trace("  starting postvalidate");
  foreach my $key ($self->zip_key, $self->mets_key) {
    my $s3path = "s3://$self->{s3}{bucket}/$key";
    my $result;

    eval { $result = $self->{s3}->s3api('head-object','--key' => $key) };

    if ($@ and $@ =~ /Not Found/) {
      $self->set_error('MissingFile',
        file => $s3path,
        detail => $@);

      return;
    }

    unless ( exists $result->{Metadata}{'content-md5'} ) {
      $self->set_error('MissingField',
        field => 'Content-MD5',
        file => $s3path,
        detail => 'No md5 checksum recorded in object metadata');

      return;
    }

    unless ( $result->{Metadata}{'content-md5'} eq $self->{checksums}{$key}  ) {
      $self->set_error('BadValue',
        field => 'Content-MD5',
        file => $s3path,
        actual => $result->{Metadata}{'content-md5'},
        expected => $self->{checksums}{$key},
        detail => 'Content-MD5 metadata value in S3 does not match expected value');

      return;
    }
  }

  get_logger->trace("  finished postvalidate");
  return 1;
  # does it have the checksum metadata?

}

sub move {
  my $self = shift;
  $self->put_object($self->mets_key,$self->{mets_source});
  $self->put_object($self->zip_key,$self->{zip_source});
}

sub put_object {
  my $self = shift;
  my $key = shift;
  my $source = shift;

  my $md5_base64 = $self->md5_base64($source);

  $self->{checksums}{$key} = $md5_base64;
  $self->{filesize}{$key} = -s $source;

  $self->{s3}->put_object($key,
    "--body",$source,
    "--content-md5" => $md5_base64,
    "--metadata" => "content-md5=" . $md5_base64);
}

sub md5_base64 {
  my $self = shift;
  my $file= shift;

  open( my $fh, "<", $file ) or croak("Can't open $file: $!");
  # From perldoc Digest::MD5:
  #
  # The base64 encoded string returned is not padded to be a multiple of 4
  # bytes long. If you want interoperability with other base64 encoded md5
  # digests you might want to append the string "==" to the result.

  return Digest::MD5->new->addfile($fh)->b64digest . '==';
}

sub record_audit {
  my $self = shift;
  $self->record_backup;
}

sub record_backup {
  my $self = shift;

  get_logger->trace("  starting record_backup");
  my $dbh = HTFeed::DBTools::get_dbh();

  my $b64_checksum = $self->{checksums}{$self->zip_key};
  my $hex_checksum = unpack("H*",decode_base64($b64_checksum));

  my $stmt =
  "insert into feed_backups (namespace, id, path, version, storage_name,
    zip_size, mets_size, saved_md5sum, lastchecked, lastmd5check, md5check_ok) \
    values(?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,1)";

  my $sth  = $dbh->prepare($stmt);
  my $rval = $sth->execute(
      $self->{namespace}, $self->{objid},
      "s3://$self->{s3}{bucket}/" . $self->object_path,
      $self->{timestamp}, $self->{name}, $self->{filesize}{$self->zip_key},
      $self->{filesize}{$self->object_path . '.mets.xml'}, $hex_checksum);

  get_logger->trace("  finished record_backup");

  return $rval;
}


1;
