#!/usr/bin/perl

package HTFeed::PackageType::EPUB::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use Image::ExifTool;
use base qw(HTFeed::PackageType::Simple::SourceMETS);


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

    $self->{mets}->add_filegroup($filegroup);
    
    1;
}

1;
