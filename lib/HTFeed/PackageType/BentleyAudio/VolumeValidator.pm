package HTFeed::PackageType::BentleyAudio::VolumeValidator;

use strict;
use warnings;
use base qw(HTFeed::PackageType::Audio::VolumeValidator);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use XML::LibXML;
use HTFeed::Stage::Fetch;
use HTFeed::XMLNamespaces qw(register_namespaces);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  $self->{stages}{validate_mp3} = \&validate_mp3;

  return $self;
}

sub validate_mp3 {
  my $self   = shift;
  my $volume = $self->{volume};
  my $path = $volume->get_staging_directory();

  my $mp3_files = $volume->get_file_groups()->{'access'}->get_filenames();

  if(!@$mp3_files ){
    $self->set_error("MissingFile", file=>"*.mp3",
      detail => "package should contain an mp3 file");
  }

  # construct mp3check command
  foreach my $mp3_file (@$mp3_files) {
    my $mp3_command = get_config('mp3val');
    my $full_command = "$mp3_command '$path/$mp3_file'";

    get_logger()->trace($full_command);
    my $output = `$full_command`;
    get_logger()->trace($output);

    my @lines = split(/\n/,$output);

    foreach my $error (grep { $_ =~ /^\s*(ERROR|WARNING)/ } @lines) {
      $self->set_error("BadFile",
        field => 'mp3val error',
        detail => $error,
      )
    }

  }

  return 1;
}

1;

