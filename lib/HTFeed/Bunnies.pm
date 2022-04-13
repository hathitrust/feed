use utf8;
use strict;
package HTFeed::Bunnies;

use Net::AMQP::RabbitMQ;
use JSON::XS qw(decode_json encode_json);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use Data::Dumper qw(Dumper);

# not defined by Net::AMQP::RabbitMQ
my $AMQP_DEFAULT_CHANNEL = 1;
my $AMQP_DELIVERY_PERSISTENT = 2;
my $BUNNY = "🐰";

sub new {
  my $class = shift;
  my %params = @_;

  my $self = {
    channel          => $params{channel}         || $AMQP_DEFAULT_CHANNEL,
    host             => $params{host}            || get_config('rabbitmq','host'),
    user             => $params{user}            || get_config('rabbitmq','user'),
    password         => $params{password}        || get_config('rabbitmq','password'),
    queue            => $params{queue}           || get_config('rabbitmq','queue'),
    priority_levels  => $params{priority_levels} || get_config('rabbitmq','priority_levels'),
    consumer_started => 0,
  };
  bless($self, $class);

  $self->connect;

  return $self;
}

sub connect {
  my $self = shift;

  my $mq = Net::AMQP::RabbitMQ->new();

  my $queue_arguments = {};
  if($self->{priority_levels} > 1) {
    $queue_arguments->{"x-max-priority"} = int($self->{priority_levels});
  }

  $mq->connect($self->{host}, { user => $self->{user}, password => $self->{password} });
  $mq->channel_open($self->{channel});
  $mq->queue_declare($self->{channel}, $self->{queue}, { durable => 1, auto_delete => 0}, $queue_arguments);
  get_logger()->debug("$BUNNY: connected to $self->{host} on channel $self->{channel} using queue $self->{queue}");

  $self->{mq} = $mq;
}

sub queue_job {
  my $self = shift;

  my %job_params = @_;

  my $props = { delivery_mode => $AMQP_DELIVERY_PERSISTENT };
  
  if($job_params{priority}) {
    $props->{priority} = $job_params{priority};
    delete $job_params{priority};
  }

  my $msg = encode_json(\%job_params);

  my $rval = $self->{mq}->publish($self->{channel},
    $self->{queue},
    $msg,
    {},
    $props,
  );

  get_logger()->debug("$BUNNY: published message on channel $self->{channel} to queue $self->{queue}");
  get_logger()->trace("$BUNNY: published message: " . Dumper($msg));
  
  return $rval;

}

# Put client in a mode where we can fetch jobs one at a time
sub start_consumer {
  my $self = shift;

  return if $self->{consumer_started};
  $self->{consumer_started} = 1;
  # only fetch one item at at time from the queue
  get_logger()->debug("$BUNNY: started consumer");
  $self->{mq}->basic_qos($self->{channel},{ prefetch_count => 1 });
  # enable calling recv; require explicit acknowledgement of message
  $self->{mq}->consume($self->{channel},$self->{queue},{ no_ack => 0 });
}

sub next_job {
  my $self = shift;
  my $timeout = shift || 0;

  $self->start_consumer;

  my $msg = $self->{mq}->recv($timeout);
  unless($msg) {
    get_logger()->debug("$BUNNY: no message (timeout was $timeout)");
    return;
  }

  get_logger()->debug("$BUNNY: received message with delivery tag $msg->{delivery_tag}");
  get_logger()->trace("$BUNNY: received message: " . Dumper($msg));

  my $job_info;
  
  eval { 
    $job_info = decode_json $msg->{body};
    get_logger()->trace("$BUNNY: deserialized message json: " . Dumper($job_info));
    die("Job was not a HASH") unless ref($job_info) eq 'HASH';
    $job_info->{msg} = $msg;
  };

  if($@) {
    get_logger()->error("Invalid job", detail => $@);
    $self->reject($msg);
  } else {
    return $job_info;
  }
  
}

sub reject {
  my $self = shift;
  my $msg = shift;

  # message may or may not be deseralized
  my $tag = $msg->{delivery_tag} || $msg->{msg}{delivery_tag};

  $self->{mq}->nack($self->{channel},$tag);
  get_logger()->debug("$BUNNY: nacked message with delivery tag $tag");
}

sub finish {
  my $self = shift;
  my $job_info = shift;
  my $tag = $job_info->{msg}{delivery_tag};

  $self->{mq}->ack($self->{channel},$tag);
  get_logger()->debug("$BUNNY: acked message with delivery tag $tag");
}

# Purge the queue of all messages
sub reset_queue {
  my $self = shift;

  $self->{mq}->purge($self->{channel},$self->{queue});
}
