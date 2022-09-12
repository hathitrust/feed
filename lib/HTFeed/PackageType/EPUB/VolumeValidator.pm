package HTFeed::PackageType::EPUB::VolumeValidator;

use strict;
use warnings;
use base qw(HTFeed::VolumeValidator);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);
use XML::LibXML;
use HTFeed::Stage::Fetch;
use HTFeed::XMLNamespaces qw(register_namespaces);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  $self->{stages}{validate_epub} = \&validate_epub;

  return $self;
}

sub validate_epub {
  my $self   = shift;
  my $volume = $self->{volume};
  my $path = $volume->get_staging_directory();

  my $epub_files = $volume->get_file_groups()->{'epub'}->get_filenames();

  if(!@$epub_files ){
    $self->set_error("MissingFile", file=>"*.epub",
      detail => "package should contain an epub file");
  }

  foreach my $epub_file (@$epub_files) {
    # construct epubcheck command
    # java -jar /l/local/epubcheck-4.0.2/epubcheck.jar 319240123458.epub -q -o -
    my $epub_command = get_config('epubcheck');
    my $full_command = "$epub_command '$path/$epub_file' -q -o -";
    get_logger()->trace($full_command);
    my $output = `$full_command`;
    
    # parse output
    my $parser = XML::LibXML->new();
    my $node = $parser->parse_string($output);
    my $xc = XML::LibXML::XPathContext->new($node);
    register_namespaces($xc);

    # is status 'Well-formed'?
    my $status = $xc->findvalue('//jhove:jhove/jhove:repInfo/jhove:status/text()');

    if ($status eq 'Well-formed') {
      return 1;
    } else {
      $self->set_error("BadFile", file=>$epub_file,
        actual => $status,
        expected => 'Well-formed',
        field => 'status',
        detail => "failed validation with epubcheck");
      return 0;
    }
  }
}

1;

