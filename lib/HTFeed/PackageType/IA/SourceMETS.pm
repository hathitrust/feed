#!/usr/bin/perl

package HTFeed::PackageType::IA::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use base qw(HTFeed::SourceMETS);
use POSIX qw(strftime);


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

    $self->_add_marc_from_file($marc_path);

    # Verify arkid in meta.xml matches given arkid
    my $parser = new XML::LibXML;
    my $metaxml = $parser->parse_file("$download_directory/${ia_id}_meta.xml");
    my $meta_arkid = $metaxml->findvalue("//identifier-ark");
    if($meta_arkid ne $volume->get_objid()) {
        $self->set_error("NotEqualValues",field=>"identifier-ark",expected=>$objid,actual=>$meta_arkid);
    }

    my $dmdsec = new METS::MetadataSection( 'dmdSec', 'id' => $self->_get_subsec_id("DMD"));
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

sub _get_capture_date {
  my $self = shift;
  my $volume = $self->{volume};
  my $xpc = $volume->get_scandata_xpc();

  my $eventdate_re = qr/^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/;
  my $eventdate = $xpc->findvalue("//scribe:scanLog/scribe:scanEvent[1]/scribe:endTimeStamp | //scanLog/scanEvent[1]/endTimeStamp");
  if(not defined $eventdate or $eventdate eq '' or $eventdate !~ $eventdate_re) {
    my $meta_xpc = $volume->get_meta_xpc();
    $eventdate = $meta_xpc->findvalue("//scandate");
  }

  if(not defined $eventdate or $eventdate eq '' or $eventdate !~ $eventdate_re) {
    $eventdate = $xpc->findvalue("//scribe:page[last()]/scribe:gmtTimeStamp | //page[last()]/gmtTimeStamp");
  }

  # if we still can't find it just use the file timestamp
  if(not defined $eventdate or $eventdate eq '' or $eventdate !~ $eventdate_re) {
    my $ia_id = $volume->get_ia_id();
    my $download_directory = $volume->get_download_directory();
    $eventdate = strftime("%Y%m%d%H%M%S",gmtime((stat("$download_directory/${ia_id}_scandata.xml"))[9]));
  }

  if ($eventdate =~ $eventdate_re) {
    # some IA packages have timestamps with hour 24 but that's not allowed in ISO format
    my $hour = $4;
    $hour = '00' if $hour eq '24'; 
    return sprintf( "%d-%02d-%02dT%02d:%02d:%02dZ", $1, $2, $3, $hour, $5, $6 );
  } else {
    $self->set_error("BadField",field => "capture time", file => "scandata.xml", actual => $eventdate);
    return undef;
  }
}

sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};
    my $premis = $self->{premis};
    my $xpc = $volume->get_scandata_xpc();

    my $capture_date = $self->_get_capture_date();
    my $scribe = $xpc->findvalue("//scribe:scanLog/scribe:scanEvent[1]/scribe:scribe | //scanLog/scanEvent[1]/scribe");

    if( $capture_date ) {

        my $eventcode = 'capture';
        my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
        $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_date);
        $eventconfig->{'executor'} = $volume->apparent_digitizer;
        # for born digital items uploaded to Internet Archive we will still use
        # 'archive' as the capture event executor - this represents capturing
        # the PDF rather than the raw images in this case, but still seems
        # appropriate given the PREMIS controlled vocabulary
        $eventconfig->{'executor'} ||= 'archive';
        $eventconfig->{'executor_type'} = $self->agent_type($eventconfig->{'executor'});
        $eventconfig->{'date'} = $capture_date;
        my $event = $self->add_premis_event($eventconfig);
        if($scribe) {
            $event->add_linking_agent(new PREMIS::LinkingAgent("tool",$scribe,"image capture"));
        }

        return 1;
    } else {
        return 0;
    }
}

1;
