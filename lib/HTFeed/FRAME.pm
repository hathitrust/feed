package HTFeed::FRAME;

use strict;
use warnings;
use HTFeed::DBTools qw(get_dbh);
use File::Temp;
use File::Copy;
use AWS;


use base qw( Exporter );
our @EXPORT_OK = qw( run );

sub new {
  my ($class, %params) = @_;

  my $self = {'dbh'  => HTFeed::DBTools::get_dbh(),
              'dest' => '/htprep/toingest/emma/',
              'bucket' => 'emma-ht-queue-production'};
  if (defined $params{'dest'}) {
    my $dest = $params{'dest'};
    $dest .= '/' unless $dest =~ m/\/$/;
    $self->{'dest'} = $dest;
  }
  if (defined $params{'bucket'}) {
    $self->{'bucket'} = $params{'bucket'};
  }
  bless $self, $class;
  return $self;
}

sub run {
  my $self = shift;

  my $last_id;
  my $ids = {}; # Set of ids for enqueue command
  # Iterate over pages of bucket list
  while (1)
  {
    # List page of EMMA bucket contents
    my $data = AWS::list_objects($self->{'bucket'}, $last_id);
    # Bail out if empty list
    last unless defined $data && scalar @{$data->{'Contents'}} > 0;
    # Iterate over page contents
    foreach my $item (@{$data->{'Contents'}})
    {
      my $file = $item->{'Key'};
      my ($id, $dir, $ext) = File::Basename::fileparse($file, '\..*');
      if (!$self->is_id_in_queue($id))
      {
        # Download IDENTIFIER.* to /htprep/toingest/emma.
        $self->download_file($id, $ext);
        $ids->{$id} = 1;
      }
      $last_id = $file;
    }
  }
  foreach my $id (keys %$ids)
  {
    my $cmd = "enqueue -p emma -n emma $id";
    print "TODO: call $cmd when HT-2700 is in place\n";
    # `$cmd`;
    # die "ERROR calling $cmd: $?" if $?;
  }
}

sub is_id_in_queue {
  my $self = shift;
  my $id   = shift;

  my $sql = 'SELECT COUNT(*) FROM feed_queue WHERE namespace = "emma" AND id = ?';
  my $row = $self->{'dbh'}->selectrow_arrayref($sql, undef, $id);
  return $row->[0] == 1;
}

sub download_file {
  my $self = shift;
  my $id   = shift;
  my $ext  = shift;

  my $tmp_file = File::Temp::tmpnam();
  AWS::get_object($self->{'bucket'}, $id . $ext, $tmp_file);
  if ($ext !~ m/^\.xml$/i && $ext !~ m/^\.zip$/i)
  {
    # If not an XML or zip file, zip the download.
    my $tmp_zip = File::Temp::tmpnam();
    my $cmd = "zip $tmp_zip $tmp_file";
    `$cmd`;
    die "Unable to zip $tmp_file from $id$ext\n" if $?;
    File::Copy::move($tmp_zip, $tmp_file);
    $ext = '.zip';
  }
  File::Copy::move($tmp_file, $self->{'dest'} . $id . $ext);
}

1;
