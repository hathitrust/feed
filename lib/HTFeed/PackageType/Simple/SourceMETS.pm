#!/usr/bin/perl

package HTFeed::PackageType::Simple::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use Image::ExifTool;
use base qw(HTFeed::SourceMETS);


sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

    );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    $self->{outfile} = "$stage_path/$pt_objid.mets.xml";
    $self->{pagedata} = sub { $volume->get_srcmets_page_data(@_); };

    return $self;
}


sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};

    my $capture_date = $volume->get_meta('capture_date');
    $self->set_error('MissingValue',file=>'meta.yml',field=>'capture_date') unless defined $capture_date;

    my $eventcode = 'capture';
    my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
    $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_date);

    $eventconfig->{'executor'} = $volume->apparent_digitizer();

    $self->set_error('MissingValue',file=>'meta.yml',field=>'capture_agent') unless defined $eventconfig->{'executor'};
    $eventconfig->{'executor_type'} = $self->agent_type($eventconfig->{'executor'});
    $eventconfig->{'date'} = $self->_add_time_zone($capture_date);
    my $capture_event = $self->add_premis_event($eventconfig);

    # also add image compression event if info present in meta.yml
    my $image_compression_date = $volume->get_meta('image_compression_date');
    my $image_compression_agent = $volume->get_meta('image_compression_agent');
    my $image_compression_tool = $volume->get_meta('image_compression_tool');
    if(defined $image_compression_date or defined $image_compression_agent or defined $image_compression_tool) {
        $self->set_error('MissingValue',file=>'meta.yml',field=>'image_compression_date') unless defined $image_compression_date;
        $self->set_error('MissingValue',file=>'meta.yml',field=>'image_compression_agent') unless defined $image_compression_agent;
        $self->set_error('MissingValue',file=>'meta.yml',field=>'image_compression_tool') unless defined $image_compression_tool;

        $eventconfig = $volume->get_nspkg()->get_event_configuration('image_compression');
        $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$image_compression_date);
        $eventconfig->{'executor'} = $image_compression_agent;
        $eventconfig->{'executor_type'} = 'HathiTrust Institution ID';
        $eventconfig->{'date'} = $self->_add_time_zone($image_compression_date);

        # make sure image compression tool is an array
        if(!ref($image_compression_tool) ) {
            $image_compression_tool = [$image_compression_tool];
        }
        if(ref($image_compression_tool) ne 'ARRAY') {
            $self->set_error('BadValue',file=>'meta.yml',field=>'image_compression_tool',expected=>'string or array',actual=>$image_compression_tool);
        }
        $eventconfig->{tools} = $image_compression_tool;
        
        $self->add_premis_event($eventconfig);
    }

    return $capture_event;
}

sub _add_dmdsecs {
    my $self = shift;
    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $preingest_directory = $volume->get_preingest_directory();
    $self->_add_marc_from_file("$preingest_directory/marc.xml");

    # add reading order info
    #  <METS:techMD ID="PD1">
    #    <METS:mdWrap LABEL="reading order" MDTYPE="OTHER" OTHERMDTYPE="Google">
    #      <METS:xmlData>
    #        <gbs:scanningOrder>left-to-right</gbs:scanningOrder>
    #        <gbs:readingOrder>left-to-right</gbs:readingOrder>
    #        <gbs:coverTag>follows-reading-order</gbs:coverTag>
    #      </METS:xmlData>
    #    </METS:mdWrap>
    #  </METS:techMD>

    my $scanning = $volume->get_meta('scanning_order');
    my $reading = $volume->get_meta('reading_order');

    if( (defined $scanning or defined $reading)
            and not (defined $scanning and defined $reading)) {
        $self->set_error('MissingValue',file=>'meta.yml',field=>'scanning_order,reading_order',detail=>"Both scanning_order and reading order must be set if either is"); 
    }

    if(defined $scanning and defined $reading) {

        if($scanning ne 'left-to-right' and $scanning ne 'right-to-left') {
            $self->set_error('BadValue',file=>'meta.yml',field=>'scanning_order',
                actual=>$scanning,expected=>'left-to-right or right-to-left');
        }

        if($reading ne 'left-to-right' and $reading ne 'right-to-left') {
            $self->set_error('BadValue',file=>'meta.yml',field=>'reading_order',
                actual=>$reading,expected=>'left-to-right or right-to-left');
        }

        my $mets = $self->{mets};
        $mets->add_schema( "gbs", "http://books.google.com/gbs");
        my $xml = <<EOT;
<gbs:scanningOrder xmlns:gbs="http://books.google.com/gbs">$scanning</gbs:scanningOrder>
<gbs:readingOrder xmlns:gbs="http://books.google.com/gbs">$reading</gbs:readingOrder>
<gbs:coverTag xmlns:gbs="http://books.google.com/gbs">follows-reading-order</gbs:coverTag>
EOT
        my $dmdsec = new METS::MetadataSection( 'dmdSec', 'id' => $self->_get_subsec_id("DMD"));
        my $parser = new XML::LibXML;
        my $parsed_xml = $parser->parse_balanced_chunk( $xml );
        $dmdsec->set_xml_node(
            $parsed_xml,
            mdtype => 'OTHER',
            othermdtype => 'Google',
            label  => 'reading order'
        );
        $self->{mets}->add_dmd_sec($dmdsec);

    }

}

# convert timezone to namespace default time zone if one is not already
# present
sub _add_time_zone {
    my $self = shift;
    my $time = shift;

    unless ($time =~ /Z$/ or $time =~ /[+-]\d{2}:\d{2}$/) {
        my $tz = $self->{volume}->get_nspkg()->get('default_timezone');
        if (defined $tz and $tz ne '') {
            $time = $self->convert_tz($time,$tz);
        }  else {
            $self->set_error('MissingValue',field => 'default_timezone',
                detail => 'Saw time without timezone in meta.yml and no default time zone for namespace specified');
        }

    }

    return $time;
}
1;
