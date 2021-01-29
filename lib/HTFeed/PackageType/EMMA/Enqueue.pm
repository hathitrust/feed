package HTFeed::PackageType::EMMA::Enqueue;

use strict;
use warnings;
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Config qw(get_config);
use HTFeed::Storage::S3;
use HTFeed::DBTools::Queue qw(enqueue_volumes);
use HTFeed::Volume;
use File::Temp qw(tempdir);
use File::Copy;

use base qw( Exporter );
our @EXPORT_OK = qw( run );

sub new {
  my ($class, %params) = @_;

  my $self = { %params };

  $self->{namespace} ||= get_config('emma','namespace');
  $self->{packagetype} ||= get_config('emma','packagetype');
  $self->{dest} ||= get_config('staging','fetch') . '/' . $self->{namespace} . '/';
  $self->{dest} .= '/' unless $self->{dest} =~ m/\/$/;

	$self->{s3} ||= HTFeed::Storage::S3->new(
    bucket => get_config('emma','bucket'),
    awscli => get_config('emma','awscli')
  );

  bless $self, $class;
  return $self;
}

# TODO: This could serve as a starting point for automating enumeration &
# download of locally-digitized material.
sub run {
  my $self = shift;

  my $last_id;
  my $ids = {}; # Set of ids for enqueue command

  my $contents = $self->{s3}->list_objects;

  foreach my $item (@{$self->{s3}->list_objects})
  {
    my $file = $item->{'Key'};
    my ($id, $dir, $ext) = File::Basename::fileparse($file, '\..*');
    if (!$self->is_id_in_queue($id))
    {
      # TODO: move this to a EMMA download stage rather than doing it here
      # Download IDENTIFIER.* to /htprep/toingest/emma.
      $self->download_file($id, $ext);
      $ids->{$id} = 1;
    }
  }

  my $volumes;
  foreach my $id (keys %$ids)
  {
    push(@$volumes, HTFeed::Volume->new(
        packagetype => $self->{packagetype},
        namespace => $self->{namespace},
        objid => $id));
  }

  # Will log any errors in queueing; what to do about those errors is not in
  # scope
  enqueue_volumes(volumes => $volumes, no_bibdata_ok => 1);

  # Not in scope for here - tracking for stuff sitting in the queue not
  # ingested, handling resubmissions
}

sub is_id_in_queue {
  my $self = shift;
  my $id   = shift;
  my $namespace = $self->{namespace};

  my $sql = 'SELECT COUNT(*) FROM feed_queue WHERE namespace = ? AND id = ?';
  my $row = get_dbh()->selectrow_arrayref($sql, undef, $namespace, $id);
  return $row->[0] == 1;
}

sub download_file {
  my $self = shift;
  my $id   = shift;
  my $ext  = shift;

  my $tmpdir = tempdir();
  my $tmpfile = "$tmpdir/$id$ext";
  $self->{s3}->get_object($self->{'bucket'}, $id . $ext, "$tmpdir/$id$ext");
  if ($ext !~ m/^\.xml$/i && $ext !~ m/^\.zip$/i)
  {
    # If not an XML or zip file, zip the download.
    my $cmd = "zip $tmpdir/$id.zip $tmpdir/$id$ext";
    system($cmd);
    die "Unable to zip $id$ext into $tmpdir/$id.zip" if $?;
    $ext = '.zip';
    $tmpfile = "$tmpdir/$id$ext";
  }
  File::Copy::move($tmpfile, $self->{'dest'});
}

1;
