package HTFeed::Storage::S3;

use Log::Log4perl qw(get_logger);
use IPC::Run qw(run);
use JSON::XS;
use strict;

sub new {
  my $class = shift;

  # expected keys:
  # bucket
  # awscli - reference to array with command to run (prefix for 's3' or 's3api')
  my $self = {
    @_
  };

  return bless($self,$class);
}

sub cmd {
  my $self = shift;

  return @{$self->{awscli}};
}

sub mb {
  my $self = shift;

  $self->s3("mb","s3://$self->{bucket}");
}

sub rb {
  my $self = shift;

  $self->s3("rb","s3://$self->{bucket}");
}

sub rm {
  my $self = shift;
  my $path = shift;
  my @args = @_;
  $self->s3("rm","s3://$self->{bucket}$path",@args);
}

sub s3 {
  my $self = shift;

  my @args = @_;
  my @fullcmd = ($self->cmd,'s3',@args);
  get_logger->trace("Running " . join(" ",@fullcmd));
  system(@fullcmd);

  die("awscli failed with status $?") if $?;
}

sub s3api {
  my $self = shift;

  my $subcommand = shift;
  my @args = @_;
  my @cmd = $self->cmd;
  my $fullcmd = [@cmd, 's3api', $subcommand, '--bucket', $self->{bucket}, @args];
  get_logger->trace("Running " . join(' ',@$fullcmd));

  my $out = "";
  my $err = "";
  run $fullcmd, \undef, \$out, \$err;
  die("awscli failed with status $?, error $err") if $?;

  return decode_json($out);
}

sub s3_has {
  my $self = shift;

  my $key = shift;

  return exists $self->list_objects("--prefix" => $key)->{$key}

}

sub head_object {
  my $self = shift;
  my $key = shift;

  return $self->s3api('head-object','--key',$key);
}

sub list_objects {
  my $self = shift;

  my $objects = $self->s3api("list-objects-v2",@_)->{Contents};

  return { map { ($_->{Key}, $_) } @$objects }
}

1;
