#!/usr/bin/perl

package HTFeed::SourceMETS;
use strict;
use warnings;
use HTFeed::METS;
use Log::Log4perl qw(get_logger);
use XML::LibXML;
use base qw(HTFeed::METS);


sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

	#		files			=> [],
	#		dir			=> undef,
	#		mets_name		=> undef,
	#		mets_xml		=> undef,
    );

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

sub clean_success {
    # clean volume preingest directory
    my $self = shift;
    return $self->{volume}->clean_preingest();
}

# do cleaning that is appropriate after failure
sub clean_failure{
    # remove partially constructed source METS file, if any
    my $self = shift;
    unlink($self->{outfile}) if defined $self->{outfile};
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
