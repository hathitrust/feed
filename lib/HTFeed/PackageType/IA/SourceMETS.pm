#!/usr/bin/perl

package HTFeed::PackageType::IA::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use base qw(HTFeed::SourceMETS);


sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

    );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    $self->{outfile} = "$stage_path/IA_" . $pt_objid . ".xml";

    return $self;
}

sub _add_header {
    my $self = shift;
    my $volume = $self->{volume};
    my $ia_id = $volume->get_ia_id();
    my $header = $self->SUPER::_add_header();
    my $objid = $volume->get_objid();
    $header->add_alt_record_id( "ia.$ia_id", type => 'IAidentifier' );
}

sub _add_dmdsecs {
    my $self = shift;
    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $download_directory = $volume->get_download_directory();
    my $ia_id = $volume->get_ia_id();
    my $marc_path = "$download_directory/${ia_id}_marc.xml";
    my $metaxml_path = "$download_directory/${ia_id}_meta.xml";

    # Validate MARC XML (if not valid, will still include and add warning)
    my $xmlschema = XML::LibXML::Schema->new(location => SCHEMA_MARC);
    my $parser = new XML::LibXML;
    my $marcxml = $parser->parse_file($marc_path);
    my $marc_xc = new XML::LibXML::XPathContext($marcxml);
    register_namespaces($marc_xc);
    $self->_remediate_marc($marc_xc);
    eval { $xmlschema->validate( $marcxml ); };
    get_logger()->warn("BadFile",file=>"marc.xml",detail => $@) if $@;
    my $marc_valid = !defined $@;

    # Verify arkid in meta.xml matches given arkid
    my $metaxml = $parser->parse_file("$download_directory/${ia_id}_meta.xml");
    my $meta_arkid = $metaxml->findvalue("//identifier-ark");
    if($meta_arkid ne $volume->get_objid()) {
        $self->_set_error("NotEqualValues",field=>"identifier-ark",expected=>$objid,actual=>$meta_arkid);
    }


    my $dmdsec = new METS::MetadataSection( 'dmdSec', 'id' => $self->_get_subsec_id("DMD"));
    $dmdsec->set_xml_node(
        $marcxml->documentElement(),
        mdtype => 'MARC',
        label  => 'IA MARC record'
    );
    $self->{mets}->add_dmd_sec($dmdsec);

    $dmdsec = new METS::MetadataSection( 'dmdSec', 'id' => $self->_get_subsec_id("DMD"));
    $dmdsec->set_xml_file(
        $metaxml_path,
        mdtype => 'OTHER',
        label  => 'IA metadata'
    );
    $self->{mets}->add_dmd_sec($dmdsec);
}

sub _add_techmds {
    my $self = shift;
    my $volume = $self->{volume};
    my $download_directory = $volume->get_download_directory();
    my $ia_id = $volume->get_ia_id();

    if ( -e "$download_directory/${ia_id}_scandata.xml" ) {
        my $scandata = new METS::MetadataSection( 'techMD',
            id => $self->_get_subsec_id('TMD'));
        $scandata->set_xml_file(
            "$download_directory/${ia_id}_scandata.xml",
            mdtype => 'OTHER',
            label  => 'IA scandata'
        );
        push( @{ $self->{amd_mdsecs} }, $scandata );
    }
    if ( -e "$download_directory/${ia_id}_scanfactors.xml" ) {
        my $scanfactors = new METS::MetadataSection( 'techMD',
            id => $self->_get_subsec_id('TMD'));
        $scanfactors->set_xml_file(
            "$download_directory/${ia_id}_scanfactors.xml",
            mdtype => 'OTHER',
            label  => 'IA scanfactors'
        );
        push( @{ $self->{amd_mdsecs} }, $scanfactors );
    }
}

sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};
    my $premis = $self->{premis};
    my $xpc = $volume->get_scandata_xpc();

    my $eventdate = $xpc->findvalue("//scribe:scanLog/scribe:scanEvent[1]/scribe:endTimeStamp | //scanLog/scanEvent[1]/endTimeStamp");
    my $scribe = $xpc->findvalue("//scribe:scanLog/scribe:scanEvent[1]/scribe:scribe | //scanLog/scanEvent[1]/scribe");

    if( $eventdate =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/ ) {

        my $capture_date
        = sprintf( "%d-%02d-%02dT%02d:%02d:%02d", $1, $2, $3, $4, $5, $6 );
        

        my $eventcode = 'capture';
        my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
        $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_date);
        $eventconfig->{'executor'} = 'CaSfIA';
        $eventconfig->{'executor_type'} = 'MARC21 Code';
        $eventconfig->{'date'} = $capture_date;
        my $event = $self->add_premis_event($eventconfig);
        if($scribe) {
            $event->add_linking_agent(new PREMIS::LinkingAgent("tool",$scribe,"image capture"));
        }
    } else {
        $self->set_error("BadField",field => "capture time", file => "scandata.xml", actual => $eventdate);
    }
}

1;
