#!/usr/bin/perl

use strict;
use warnings;

#use FindBin;
#use lib "$FindBin::Bin/../../lib";

use File::Basename;
use File::Pairtree qw(ppath2id s2ppchars);

package HTFeed::RepositoryIterator;

# The only restriction on `path` is that it must have a component ending with `sdrX`
# where X is one or more digits
sub new {
  my $class = shift;
  my $path  = shift;

  # Remove trailing slash from path if necessary
  $path =~ s!/$!!;
  my @pathcomp = split('/', $path);
  # remove base & any empty components
  #@pathcomp = grep { $_ ne '' } @pathcomp;
  my $sdr_partition = undef;
  if ($path =~ qr#/?sdr(\d+)/?#) {
    $sdr_partition = $1;
  } else {
    die "Cannot infer SDR partition from $path";
  }
  my $self = {
    # The path to traverse. May be a subpath like /tmp/sdr1/obj/test
    path => $path,
    sdr_partition => $sdr_partition,
    objects_processed => 0,
  };
  bless($self, $class);
  return $self;
}

sub next_object {
  my $self = shift;

  my $obj = undef;
  while (1) {
    my $line = readline($self->_find_pipe);
    last unless defined $line;
    chomp $line;
    # ignore temporary location
    next if $line =~ qr(obj/\.tmp);
    next if $line =~ /\Qpre_uplift.mets.xml\E/;
    #next if $self->_recent_previous_version($line);

    my ($file_objid, $path, $type) = File::Basename::fileparse($line, qr/\.mets\.xml/, qr/\.zip/);
    # Remove trailing slash
    $path =~ s!/$!!; 
    next if $self->{prev_path} and $path eq $self->{prev_path};

    $self->{objects_processed}++;
    $self->{prev_path} = $path;

    # Remove everything up to and including the `sdrX/`
    my $subpath = $path;
    $subpath =~ s!.*?sdr\d+/!!;
    my @pathcomp = split('/', $subpath);
    @pathcomp = grep { $_ ne '' } @pathcomp;
    my $namespace = $pathcomp[1];
    my $directory_objid  = $pathcomp[-1];
    my $objid = File::Pairtree::ppath2id(join('/', @pathcomp));
    $obj = {
      path => $path,
      namespace => $namespace,
      # Caller should make sure all three of these are equivalent
      objid => $objid,
      file_objid => $file_objid,
      directory_objid => $directory_objid,
      # This is simple concatenation. Might be more interesting to return the actual contents of the directory.
      #zipfile => "$path/$file_objid.zip",
      #metsfile => "$path/$file_objid.mets.xml",
      contents => $self->_contents($path),
    };
    last;
  }
  return $obj;
}

sub close {
  my $self = shift;

  if ($self->{find_pipe}) {
    close $self->{find_pipe};
    $self->{find_pipe} = undef;
  }
}

# Returns a sorted arrayref with filenames (not full paths) in
# an object directory. Excludes . and ..
sub _contents {
  my $self = shift;
  my $path = shift;

  my @contents;
  opendir(my $dh, $path);
  while ( my $file = readdir($dh) ) {
    next if $file eq '.' or $file eq '..';
    push(@contents, $file);
  }
  @contents = sort @contents;
  return \@contents;
}

sub _find_pipe {
  my $self = shift;

  if (!$self->{find_pipe}) {
    my $find_pipe;
    my $find_cmd = "find $self->{path} -follow -type f|";
    open($find_pipe, $find_cmd) or die("Can't open pipe to find: $!");
    $self->{find_pipe} = $find_pipe;
  }
  return $self->{find_pipe};
}

# NOTE: is this needed?
# Does file end with `.old` suffix and is it less than 48 hours old?
sub _recent_previous_version {
  my $self = shift;
  my $file = shift;

  if ($file =~ /.old$/) {
    my $ctime = ( stat($file) )[10];
    my $ctime_age = time() - $ctime;
    return 1 if $ctime_age < (86400 * 2);
  }
}

1;
