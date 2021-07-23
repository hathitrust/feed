#!/usr/bin/perl
package HTFeed::StorageAudit::PrefixedVersions;

use strict;
use warnings;
use Carp;
use Log::Log4perl qw(get_logger);
use File::Temp;

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

use base qw(HTFeed::StorageAudit);

# This is Data Den specific.
# obj_dir/namespace/3-char-prefix/id.version.ext
sub parse_object_path {
  my $self = shift;
  my $path = shift;

  my @pathcomp = split(m/\//, $path);
  die "Unable to extract object fields from $path" unless scalar @pathcomp > 3;
  my $file = pop @pathcomp;
  my ($id, $version, $ext) = split(m/\./, $file, 3);
  my $obj = { obj_dir   => join('/', @pathcomp),
              version   => $version,
              namespace => $pathcomp[-2],
              objid     => HTFeed::StorageAudit::ppchars2s($id),
              file      => $file};
  $obj->{id} = join '.', $obj->{namespace}, $obj->{objid}, $obj->{version};
  return $obj;
}

1;

__END__
