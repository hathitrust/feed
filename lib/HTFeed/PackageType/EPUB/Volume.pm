package HTFeed::PackageType::EPUB::Volume;

use warnings;
use strict;
use base qw(HTFeed::PackageType::Simple::Volume);
use HTFeed::Config;
use Log::Log4perl qw(get_logger);
use YAML::Any qw(LoadFile);
use Carp qw(croak);
use Archive::Zip qw(:ERROR_CODES :CONSTANTS) ;

sub get_file_groups {
  my $self = shift;

  if(not defined $self->{filegroups}) {
    $self->SUPER::get_file_groups();

    my $zip = Archive::Zip->new();
    my $epub = $self->get_epub_path();
    $zip->read($epub) == AZ_OK
      or die("Can't read $epub as zip");

    $self->{filegroups}{epub_contents}  = HTFeed::FileGroup->new([$zip->memberNames],
            prefix => 'EPUBCONTENTS',
            use => 'epub contents',
            file_pattern => qr/[a-zA-Z0-9._-]+\.epub$/,
            required => 0,
            sequence => 0,
            content => 0,
            jhove => 0,
            utf8 => 0,
            structmap => 0);

  }

  return $self->{filegroups};

}

sub get_epub_path {
  my $self = shift;

  return (glob($self->get_preingest_directory() . "/*epub"))[0];

}

1;
