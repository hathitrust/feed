#!/usr/bin/perl

package HTFeed::PackageType::EMMA::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use Image::ExifTool;
use HTFeed::DBTools qw(get_dbh);
use base qw(HTFeed::SourceMETS);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        @_,
    );

    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();

    $self->{outfile} = "$stage_path/$pt_objid.mets.xml";
    $self->{profile} = "http://www.hathitrust.org/documents/hathitrust-emma-mets-profile1.0.xml";


    return $self;
}

sub run {
  my $self = shift;

  $self->_load_emma_xml;

  $self->SUPER::run(@_);
}

sub _load_emma_xml {
  my $self = shift;
  my $volume = $self->{volume};
  my $namespace = $volume->get_namespace();
  my $objid = $volume->get_objid();
  my $sip_directory = $volume->get_sip_directory();

  $self->{emma_xml_path} = "$sip_directory/$namespace/$objid.xml";

  my $parser = new XML::LibXML;
  my $emma_xml = $parser->parse_file($self->{emma_xml_path});
  my $emma_xc = new XML::LibXML::XPathContext($emma_xml);
  register_namespaces($emma_xc);

  $self->{emma_xml} = $emma_xml->documentElement();
  $self->{emma_xc} = $emma_xc;

  $self->_validate_remediation_metadata;
  $self->_cache_remediation_metadata;

}

sub _validate_remediation_metadata {
  my $self = shift;

  # ensure the XML is actually about this object

  my $emma_submission_id = $self->{emma_xc}->findvalue('//emma:SubmissionPackage/@submission_id');
  my $objid = $self->{volume}->get_objid();

  if ($objid ne $emma_submission_id) {
    $self->set_error("BadValue",
      details => "Submission ID in EMMA XML does not match filename",
      field => 'submission_id',
      file => $self->{emma_xml_path},
      actual => $emma_submission_id,
      expected => $objid);
  }

}

sub _add_dmdsecs {
  my $self = shift;

  my $dmdsec = new METS::MetadataSection( 'dmdSec', 'id' => $self->_get_subsec_id("DMD"));
  $dmdsec->set_xml_node(
    $self->{emma_xml},
    mdtype => 'OTHER',
    othermdtype => 'EMMA',
    label  => 'remediation metadata'
  );
  $self->{mets}->add_dmd_sec($dmdsec);
}

sub _cache_remediation_metadata {
  my $self = shift;
  my $emma_xc = $self->{emma_xc};

  my $remediated_item_id = $self->{volume}->get_namespace() . '.' . $self->{volume}->get_objid();
  my $original_item_id = $emma_xc->findvalue('//emma:emma_repositoryRecordId');
  my $dc_format = $emma_xc->findvalue('//emma:dc_format');
  my $rem_coverage = join(", ", map { $_->textContent } $emma_xc->findnodes('//emma:rem_coverage/xs:string'));
  my $rem_remediation= $emma_xc->findvalue('//emma:rem_remediation');

  my $creation_date = $emma_xc->findvalue('//emma:emma_lastRemediationDate');
  $self->set_error('MissingValue',
    file=>$self->{emma_xml_path},
    field=>'emma_lastRemediationDate') unless defined $creation_date;

  $self->{creation_date} = $creation_date;

  my $sth = get_dbh()->prepare("REPLACE INTO emma_items (remediated_item_id, original_item_id, dc_format, rem_coverage, rem_remediation) VALUES (?,?,?,?,?)");

  $sth->execute($remediated_item_id,$original_item_id,$dc_format,$rem_coverage,$rem_remediation);
}

sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};

    my $eventcode = 'creation';
    my $eventid = $volume->make_premis_uuid($eventcode,$self->{creation_date});
    my $event = PREMIS::Event->new($eventid,
      'UUID',
      'creation',
      $self->{creation_date},
      "Creation of remediated version");

    $self->{included_events}{$eventid} = $event;
    $self->{premis}->add_event($event);

    return $event;
}

sub _add_struct_map {
  my $self = shift;
  my $mets   = $self->{mets};
  my $volume = $self->{volume};

  # add empty structMap
  my $struct_map = METS::StructMap->new();
  my $div = METS::StructMap::Div->new();

  $struct_map->add_div($div);
  $mets->add_struct_map($struct_map);
}

1;
