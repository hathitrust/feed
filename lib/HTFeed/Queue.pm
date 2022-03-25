package HTFeed::Queue;

=description
    Interactions with the feed_queue table

=cut

use warnings;
use strict;
use Carp;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Bunnies;

use Log::Log4perl qw(get_logger);

our @EXPORT = qw(enqueues reset);

sub new {
  my $class = shift;

  my $self = {};

  $self->{dbh} = get_dbh();

  return bless($self, $class);
}

=item enqueue
Put an item on the queue to be ingested.
=synopsis
enqueue(
        volume => $volume,
        status        => $status_string,
        ignore        => 1,
        priority      => 1|2|3|,
        use_disallow_list => 0,
)

All items queued with higher-number priorities will be processed before
lower-number priority items.

=cut

sub enqueue{
  my $self = shift;

  my %args = @_;
  
  $args{use_disallow_list} = 1 unless defined $args{use_disallow_list};
  $args{priority} = 0 unless defined $args{priority};

  my $volume = $args{volume};

  my $rval = eval {
    my $status = $args{status};
    $status ||= $volume->get_nspkg()->get('default_queue_state');

    $self->{dbh}->begin_work();

    unless ($args{no_bibdata_ok} || $self->has_bibdata($volume)) {
      $self->{dbh}->rollback && return 0 
    }

    if ($args{use_disallow_list} && $self->disallowed($volume)) {
      $self->{dbh}->rollback && return 0;
    }

    # DBI returns '0E0' (0 but true) if the insert statement was successful but no rows
    # were inserted
    my $inserted = $self->queue_db($volume,$status,$args{ignore});
    $self->mark_returned($volume) if($inserted and !$args{no_bibdata_ok});
    $self->send_to_message_queue($volume,$status,$args{priority}) if $inserted == 1;

    $self->{dbh}->commit();

    return $inserted == 1;
  };
  if($@) {
    $self->{dbh}->rollback();
    get_logger()->error($@);
  }

  return $rval;

}

# reset(\@volumes, $reset_level)
# 
# reset punted and done volumes. reset level determines which:
#  0: nothing
#  1: punted
#  2: punted, collated, rights, done
#  3: everything (including "in-flight" volumes; use with care)
=item reset
reset volumes
=synopsis
reset(
        (volume => $volume),
        [force => 1]
        [status => $status]
        [reset_level => $reset_level]
);
=cut
sub reset {
  my $self = shift;

  my %args = (
    volume  => undef,
    reset_level   => undef,
    status  => undef,
    priority => 0,
    @_
  );

  die "Reset level should be >0 and <=3" if not defined $args{reset_level} or $args{reset_level} < 1 or $args{reset_level} > 3;

  my $volumes = $args{volumes};
  $volumes = [$args{volume}]
  if (defined $args{volume});

  my $reset_level = $args{reset_level};
  my $status = $args{status};

  my $dbh = HTFeed::DBTools::get_dbh();
  my $sth;
  if($reset_level == 3){
    $sth = $dbh->prepare(q(UPDATE feed_queue SET node = NULL, pkg_type = ?, status = ?, failure_count = 0 WHERE namespace = ? and id = ?;));
  } else {
    my $statuses = "";
    $statuses = "('punted')" if $reset_level == 1;
    $statuses = "('punted','collated','rights','done')" if $reset_level == 2;
    $sth = $dbh->prepare(qq(UPDATE feed_queue SET node = NULL, pkg_type = ?, status = ?, failure_count = 0 WHERE status in $statuses and namespace = ? and id = ? and node is null;));
  }

  my @results;
  foreach my $volume (@{$volumes}){
    # use default initial state from pkgtype def if not given one
    if(not defined $status) {
      $status = $volume->get_nspkg()->get('default_queue_state');
    }
    my $res = $sth->execute($volume->get_packagetype(),$status,$volume->get_namespace, $volume->get_objid);
    push @results, $res;
    $self->send_to_message_queue($volume,$status,$args{priority}) if $res == 1;
  }
  return \@results;
}

sub message_queue {
  my $self = shift;
  $self->{message_queue} ||= HTFeed::Bunnies->new();
}

sub disallowed {
  my $self = shift;
  my $volume = shift;

  $self->{disallow_sth} ||= $self->{dbh}->prepare("SELECT namespace, id FROM feed_queue_disallow WHERE namespace = ? and id = ?");

  $self->{disallow_sth}->execute($volume->get_namespace,$volume->get_objid);
  if($self->{disallow_sth}->fetchrow_array()) {
    get_logger()->warn("Disallowed",namespace=>$volume->get_namespace,objid=>$volume->get_objid);
    return 1;
  } else {
    return 0;
  }
}


sub has_bibdata {
  my $self = shift;
  my $volume = shift;

  $self->{has_bibdata_sth} ||= $self->{dbh}->prepare("SELECT namespace, id FROM feed_zephir_items WHERE namespace = ? and id = ?");

  $self->{has_bibdata_sth}->execute($volume->get_namespace, $volume->get_objid);
  if($self->{has_bibdata_sth}->fetchrow_array()) {
    return 1;
  } else {
    get_logger()->warn("NoBibData",namespace=>$volume->get_namespace,objid=>$volume->get_objid);
    return 0;
  }
}

sub mark_returned { 
  my $self = shift;

  my $volume = shift;
  $self->{return_sth} ||= $self->{dbh}->prepare("UPDATE feed_zephir_items SET returned = '1' WHERE namespace = ? and id = ?");

  $self->{return_sth}->execute($volume->get_namespace, $volume->get_objid);
}


sub queue_sth {
  my $self = shift;

  $self->{queue_sth} ||= $self->{dbh}->prepare("INSERT INTO feed_queue (pkg_type, namespace, id, status) VALUES (?,?,?,?);");
}

sub queue_ignore_existing_sth {
  my $self = shift;

  $self->{queue_ignore_sth} ||= $self->{dbh}->prepare("INSERT IGNORE INTO feed_queue (pkg_type, namespace, id, status) VALUES (?,?,?,?);");
}

sub queue_db {
  my $self = shift;
  my ($volume, $status, $ignore) = @_;

  my $sth = $ignore ? $self->queue_ignore_existing_sth : $self->queue_sth;

  my $rval = $sth->execute($volume->get_packagetype, $volume->get_namespace, $volume->get_objid, $status);

  if(!$rval) {
    die("INSERT returned false");
  } elsif ($rval > 1) {
    # shouldn't happen
    die("INSERT inserted $rval rows");
  }

  return $rval;

}

sub send_to_message_queue {
  my $self = shift;
  my $volume = shift;
  my $status = shift;
  my $priority = shift;

  # feature gate
  return unless get_config('use_rabbitmq');
  return if grep { $_ eq $status } @{get_config('release_states')};

  my $q = $self->message_queue;

  # TODO: We could look at trying to handle publisher confirms; updating the
  # queue to 'queued' when we get an ack and redelivering the message when we
  # get a nack. The documentation does not recommend synchronously waiting for
  # an ack, since that may take several hundred milliseconds:
  # https://www.rabbitmq.com/confirms.html#publisher-confirms
  #
  # It would probably make more sense to queue everything we want to queue , then
  # wait for acks/nacks. (alternatively, we could do so every time we queue N items)
  
  $q->queue_job(
    namespace    => $volume->get_namespace,
    id           => $volume->get_objid,
    pkg_type     => $volume->get_packagetype,
    status       => $status,
    priority     => $priority
  );

}


1;

__END__

