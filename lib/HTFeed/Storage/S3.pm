package HTFeed::Storage::S3;

use Log::Log4perl qw(get_logger);
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
  my $fullcmd = join(" ",@cmd) . " s3api $subcommand --bucket $self->{bucket} " . join(" ",@args);
  get_logger->trace("Running $fullcmd");
  my $result = `$fullcmd`;
  die("awscli failed with status $?") if $?;

  return decode_json($result);
}

sub s3_has {
  my $self = shift;

  my $key = shift;

  my $result = $self->s3api("list-objects","--prefix",$key);

  return grep { $_->{Key} eq $key } @{$result->{Contents}}

}

1;
