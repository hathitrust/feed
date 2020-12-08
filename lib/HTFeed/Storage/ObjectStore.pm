package HTFeed::Storage::ObjectStore;

use Carp;
use Log::Log4perl qw(get_logger);
use HTFeed::Storage;
use File::Pairtree qw(id2ppath s2ppchars);
use POSIX qw(strftime);
use HTFeed::Storage::S3;

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

sub object_path {
  my $self = shift;

  $self->{timestamp} ||= strftime("%Y%m%d%H%M%S",gmtime);

  return join(".",
    $self->{namespace},
    s2ppchars($self->{objid}),
    $self->{timestamp});
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

sub postvalidate {
  my $self = shift;

  my $prefix = $self->object_path;

  foreach my $suffix ($self->zip_suffix, ".mets.xml") {
    my $key = $prefix . $suffix;
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

  return 1;
  # does it have the checksum metadata?

}

sub move {
  my $self = shift;
  $self->put_mets;
  $self->put_zip;
}

sub put_mets {
  my $self = shift;

  $self->put_object($self->object_path . ".mets.xml",$self->{volume}->get_mets_path());
}

sub put_zip {
  my $self = shift;

  $self->put_object($self->object_path . $self->zip_suffix,$self->zip_source);
}

sub put_object {
  my $self = shift;
  my $key = shift;
  my $source = shift;

  my $md5_base64 = $self->md5_base64($source);

  $self->{checksums}{$key} = $md5_base64;

  $self->{s3}->s3api("put-object",
    "--key" => $key,
    "--body" => $source,
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


1;
