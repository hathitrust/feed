#!/usr/bin/perl

package HTFeed::SourceMETS;
use strict;
use warnings;
use HTFeed::METS;
use Log::Log4perl qw(get_logger);
use XML::LibXML;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use base qw(HTFeed::METS);
use File::Basename qw(basename dirname);
use HTFeed::Stage::Download;

sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

	#		files			=> [],
	#		dir			=> undef,
	#		mets_name		=> undef,
	#		mets_xml		=> undef,
    );

    # override default pagedata source
    delete $self->{pagedata};
    $self->{required_events} = ["capture"];

    return $self;
}

sub _add_premis {
    my $self = shift;
    my $volume = $self->{volume};

    # map from UUID to event - events that have already been added
    # for source METS this will be empty
    $self->{included_events} = {};

    my $premis = new PREMIS;
    $self->{premis} = $premis;

    # last chance to record
    $volume->record_premis_event('source_mets_creation');
    $volume->record_premis_event('page_md5_create');
    $volume->record_premis_event('mets_validation');

    # create PREMIS object
    my $premis_object = new PREMIS::Object('identifier',$volume->get_identifier());
    # FIXME: not used in source METS??
#    $premis_object->set_preservation_level("1");
#    $premis_object->add_significant_property('file count',$volume->get_file_count());
#    $premis_object->add_significant_property('page count',$volume->get_page_count());
    $premis->add_object($premis_object);

    $self->_add_capture_event();
    $self->_add_premis_events($volume->get_nspkg()->get('source_premis_events'));

    my $digiprovMD =
      new METS::MetadataSection( 'digiprovMD', 'id' => 'premis1' );
    $digiprovMD->set_xml_node( $premis->to_node(), mdtype => 'PREMIS' );

    push( @{ $self->{amd_mdsecs} }, $digiprovMD);
}

sub _check_premis {
  my $self = shift;
}

sub stage_info{
    return {success_state => 'src_metsed', failure_state => 'punted'};
}


# Override base class: just add content FGs
sub _add_filesecs {
    my $self   = shift;

    $self->_add_content_fgs();
}

sub clean_always {
    # do nothing
}

# Override base class: source METS don't need the sourcemd
sub _add_sourcemd {
    # do nothing
}


# Clean volume preingest directory
sub clean_success {
    my $self = shift;
    return $self->{volume}->clean_preingest();
}

# do cleaning that is appropriate after failure
# remove partially constructed source METS file, if any
sub clean_failure{
    my $self = shift;
    unlink($self->{outfile}) if defined $self->{outfile};
}

sub _get_marc_from_zephir {
  my $self = shift;
  my $marc_path = shift;

  my $identifier = $self->{volume}->get_identifier();

  HTFeed::Stage::Download::download($self,
    url => "http://zephir.cdlib.org/api/item/" . $self->{volume}->get_identifier(),
    path => dirname($marc_path),
    filename => basename($marc_path));
    
}

sub _add_marc_from_file {
    my $self = shift;
    my $marc_path = shift;

    if(! -e $marc_path) {
       _get_marc_from_zephir($self,$marc_path);
    }

#    # Validate MARC XML (if not valid, will still include and add warning)
#    my $xmlschema = XML::LibXML::Schema->new(location => SCHEMA_MARC);
#    my $parser = new XML::LibXML;
#    my $marcxml = $parser->parse_file($marc_path);
#    my $marc_xc = new XML::LibXML::XPathContext($marcxml);
#    register_namespaces($marc_xc);
#    $self->_remediate_marc($marc_xc);
#    eval { $xmlschema->validate( $marcxml ); };
#    get_logger()->warn("BadFile",file=>"marc.xml",detail => $@) if $@;
#    my $marc_valid = !defined $@;

    my $dmdsec = new METS::MetadataSection( 'dmdSec', 'id' => $self->_get_subsec_id("DMD"));
    $dmdsec->set_xml_node(
        $marcxml->documentElement(),
        mdtype => 'MARC',
        label  => 'MARC record'
    );
    $self->{mets}->add_dmd_sec($dmdsec);
}

1;

__END__
