#!/usr/bin/perl

package HTFeed::PackageType::IA::SourceMETS;
use strict;
use warnings;
use HTFeed::METS;
use Log::Log4perl qw(get_logger);
use File::Path qw(remove_tree);
use XML::LibXML;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use base qw(HTFeed::METS);

my $logger = get_logger(__PACKAGE__);

sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

	#		files			=> [],
	#		dir			=> undef,
	#		mets_name		=> undef,
	#		mets_xml		=> undef,
    );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    my $mets_path = "$stage_path/IA_" . $pt_objid . ".xml";
    $self->{outfile} = $mets_path;

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
    $logger->warn("WARNING: marc.xml is not valid: $@ \n") if $@;
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

# TODO: good candidate for base SourceMETS class
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

# TODO: factor out common stuff to SourceMETS.pm
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
        my $detail = $eventconfig->{'detail'} 
        or $self->set_error("MissingField",field => "event detail", detail => "Missing event detail for $eventcode");
        my $eventtype = $eventconfig->{'type'}
        or $self->set_error("MissingField",field => "event type", detail => "Missing event type for $eventcode");

        my $eventid = $volume->make_premis_uuid($eventtype,$capture_date);
        my $event = new PREMIS::Event($eventid, 'UUID', $eventtype, $capture_date, $detail);
        $event->add_linking_agent( new PREMIS::LinkingAgent( 'MARC21 Code', "CaSfIA", 'Executor' ) );
        if($scribe) {
            $event->add_linking_agent(new PREMIS::LinkingAgent("tool",$scribe,"image capture"));
        }
        $premis->add_event($event);
    } else {
        $self->set_error("BadField",field => "capture time", file => "scandata.xml", actual => $eventdate);
    }
}

sub stage_info{
    return {success_state => 'src_metsed', failure_state => ''};
}


# Override base class: just add content FGs
# TODO: factor out to base SourceMETS
sub _add_filesecs {
    my $self   = shift;

    $self->_add_content_fgs();

}

sub clean_always {
    # do nothing
}

sub clean_success {
    # clean volume preingest directory
    my $self = shift;
    my $dir = $self->{volume}->get_preingest_directory();
    
    return remove_tree $dir;
}

# do cleaning that is appropriate after failure
sub clean_failure{
    # remove partially constructed source METS file, if any
    my $self = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $stage_path = $volume->get_staging_directory();
    my $objid = $volume->get_objid();
    my $mets_path = "$stage_path/IA" . $objid . ".xml";

    unlink($mets_path);
}

# Basic structMap with no page labels.
# TODO: factor out to base SourceMETS subclass
sub _add_struct_map {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $struct_map = new METS::StructMap( id => 'SM1', type => 'physical' );
    my $voldiv = new METS::StructMap::Div( type => 'volume' );
    $struct_map->add_div($voldiv);
    my $order               = 1;
    my $file_groups_by_page = $volume->get_file_groups_by_page();
    foreach my $seqnum ( sort( keys(%$file_groups_by_page) ) ) {
        my $pagefiles   = $file_groups_by_page->{$seqnum};
        my $pagediv_ids = [];
        while ( my ( $filegroup_name, $files ) = each(%$pagefiles) ) {
            foreach my $file (@$files) {
                my $fileid =
                  $self->{filegroups}{$filegroup_name}->get_file_id($file);
                if ( not defined $fileid ) {
                    $self->set_error(
                        "MissingField",
                        field     => "fileid",
                        file      => $file,
                        filegroup => $filegroup_name,
                        detail    => "Can't find ID for file in file group"
                    );
                    next;
                }

                push( @$pagediv_ids, $fileid );
            }
        }
        $voldiv->add_file_div(
            $pagediv_ids,
            order => $order++,
            type  => 'page',
        );
    }
    $mets->add_struct_map($struct_map);

}

1;
