#!/usr/bin/perl

package HTFeed::PackageType::EPUB::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use Image::ExifTool;
use base qw(HTFeed::PackageType::Simple::SourceMETS);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        @_,
    );
    $self->{profile} = "http://www.hathitrust.org/documents/hathitrust-epub-mets-profile1.0.xml";

    return $self;
}

sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};

    my $creation_date = $volume->get_meta('creation_date');
    $self->set_error('MissingValue',file=>'meta.yml',field=>'creation_date') unless defined $creation_date;

    my $eventcode = 'creation';
    my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
    $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$creation_date);
    $eventconfig->{'executor'} = $volume->get_meta('creation_agent');
    $self->set_error('MissingValue',file=>'meta.yml',field=>'creation_agent') unless defined $eventconfig->{'executor'};
    $eventconfig->{'executor_type'} = 'HathiTrust Institution ID';
    $eventconfig->{'date'} = $creation_date;
    my $creation_event = $self->add_premis_event($eventconfig);

    return $creation_event;
}

sub _add_content_fgs {
    my $self   = shift;
    my $volume = $self->{volume};
    $self->SUPER::_add_content_fgs(@_);

    # get filegroup info from meta.yml
    my $epub_fg_info = $volume->get_meta('epub_contents');

    my $filegroup = METS::FileGroup->new(
      id => $self->_get_subsec_id("FG"),
      use => "epub contents",
    );

    foreach my $subsec  (qw(container mimetype rootfile manifest)) {
      foreach my $file (@{$epub_fg_info->{$subsec}}) {
        my $t = Date::Manip::Date->new();
        $t->parse($file->{created});
        $t->convert("UTC");
        $file->{created} = $t->printf("%OZ");
        $filegroup->add_file($file->{filename},
          %$file,
          prefix => 'EPUBCONTENTS'
        );
      }
    }

    $self->{filegroups}{"epub contents"} = $filegroup;
    $self->{mets}->add_filegroup($filegroup);

    1;
}

sub _add_struct_map {
  my $self = shift;
  my $mets   = $self->{mets};
  my $volume = $self->{volume};
  my $epub_spine = $volume->get_meta('epub_contents')->{'spine'};

  my $counter = 0;
  my $epub_fg = $self->{filegroups}{"epub contents"};
  my $text_fg = $self->{filegroups}{text};

  my $struct_map = new METS::StructMap( id => 'SM1', type => 'physical' );
  my $voldiv = new METS::StructMap::Div( type => 'volume' );
  $struct_map->add_div($voldiv);

  # for each epub xhtml
  foreach my $filename (@{$epub_spine}) {
    $counter++;

    my $epub_id = $epub_fg->get_file_id($filename);

    # find ID for corresponding text file
    my $txt_file = sprintf("%08d",$counter) . ".txt";
    my $txt_id = $text_fg->get_file_id($txt_file);

    my $pagedata = $volume->get_meta('pagedata')->{$filename};

    $voldiv->add_file_div(
        [$epub_id, $txt_id],
        order => $counter,
        type  => 'chapter',
        %$pagedata
    );

  }

  $mets->add_struct_map($struct_map);
}

1;
