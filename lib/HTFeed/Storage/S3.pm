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

sub cp_to {
  my $self = shift;
  my $src = shift;
  my $path = shift;

  return $self->s3('cp',$src,"s3://$self->{bucket}/$path",@_);
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

  return 1;
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
  # Bail out with undef if result is empty string, which is not valid JSON.
  return unless length $out;
  return decode_json($out);
}

sub s3_has {
  my $self = shift;
  my $key = shift;

  my $results = $self->list_objects("--prefix" => $key);
  return grep { $_->{Key} eq $key } @$results;
}

sub head_object {
  my $self = shift;
  my $key = shift;

  return $self->s3api('head-object','--key',$key,@_);
}

sub get_object {
  my $self = shift;
  my $bucket = shift;
  my $key = shift;
  my $dest = shift;

  return $self->s3api('get-object','--key',$key,@_,$dest);
}

sub restore_object {
  my $self = shift;
  my $key = shift;

  return $self->s3api('restore-object','--key',$key,@_);
}

sub list_objects {
  my $self = shift;

  my $objects = [];
  my @params = @_;
  my @next_token_params = ();

  while(1) {
    my $result = $self->s3api("list-objects-v2",@next_token_params,@params);
    last unless $result;

    push(@$objects,@{$result->{Contents}});
    last unless $result->{NextToken};

    @next_token_params = ('--starting-token',$result->{NextToken});
  }
  return $objects;
}

1;
