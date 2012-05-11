#!/usr/bin/perl

package HTFeed::PackageType::DLXS::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use base qw(HTFeed::SourceMETS);
use HTFeed::METS;
use Image::ExifTool;


sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

    );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    $self->{outfile} = "$stage_path/DLXS_" . $pt_objid . ".xml";
    $self->{pagedata} = sub { $volume->get_srcmets_page_data(@_); };

    return $self;
}

# capture event is recorded in ImageRemediate stage
sub _add_capture_event {
    return;
}

sub _add_dmdsecs {
    my $self = shift;
    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $preingest_directory = $volume->get_preingest_directory();
    my $xml_path = "$preingest_directory/$objid.hdr";

    if(-e $xml_path) {

        my $dmdsec = new METS::MetadataSection( 'dmdSec', 'id' => $self->_get_subsec_id("DMD"));
        $dmdsec->set_xml_file(
            $xml_path,
            mdtype => 'TEIHDR',
        );
        $self->{mets}->add_dmd_sec($dmdsec);
    }
}

1;
