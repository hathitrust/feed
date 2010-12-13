#!/usr/bin/perl

package HTFeed::PackageType::Yale::SourceMETS;
use HTFeed::METS;
use base qw(HTFeed::METS);
use strict;
use warnings;
use File::Path qw(remove_tree);

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
    my $objid = $volume->get_objid();
    my $mets_path = "$stage_path/Yale_" . $objid . ".xml";
    $self->{outfile} = $mets_path;

    return $self;
}

sub stage_info{
    return {success_state => 'src_metsed', failure_state => ''};
}

sub _add_dmdsecs {
    my $self   = shift;
    my $volume = $self->{volume};
    my $mets   = $self->{mets};
    my $objid = $volume->get_objid();

    my $preingest_dir = $volume->get_preingest_directory();
    my $metadata_dir = "$preingest_dir/METADATA";

    $self->_add_dmd_sec(
        'DMD1', 'MARC',
        'Yale MARC record',
        "$metadata_dir/${objid}_MRC.xml"
    );
    $self->_add_dmd_sec(
        'DMD2', 'MODS',
        'MODS metadata',
        "$metadata_dir/${objid}_MODS.xml"
    );
    $self->_add_dmd_sec(
        'DMD3', 'DC',
        'OAI/DC metadata',
        "$metadata_dir/${objid}_OAIDC.xml"
    );

}

sub _add_techmds {

    # TODO: include scandata - need to not add amd sec in add_premis??

}

sub _add_premis {
    my $self = shift;
    my $volume = $self->{volume};

    # map from UUID to event - events that have already been added
    # for source METS this will be empty
    $self->{included_events} = {};

    my $premis = new PREMIS;

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

    $self->_add_capture_event($premis);
    $self->_add_premis_events($premis,$volume->get_nspkg()->get('source_premis_events'));

    my $digiprovMD =
      new METS::MetadataSection( 'digiprovMD', 'id' => 'premis1' );
    $digiprovMD->set_xml_node( $premis->to_node(), mdtype => 'PREMIS' );
    $self->{'mets'}->add_amd_sec( 'AMD1', $digiprovMD);
}

sub _add_capture_event {
    my $self = shift;
    my $premis = shift;
    my $volume = $self->{volume};
    # Add the custom capture event, extracting info from the Yale METS
    my $eventcode = 'capture';
    my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
    my $detail = $eventconfig->{'detail'} 
	or $self->set_error("MissingField",field => "event detail", detail => "Missing event detail for $eventcode");
    my $eventtype = $eventconfig->{'type'}
	or $self->set_error("MissingField",field => "event type", detail => "Missing event type for $eventcode");
    my $capture_date = $volume->get_capture_time()
	or $self->set_error("MissingField",field => "event datetime",detail => "Missing event tiem for $eventcode");

    my $eventid = $volume->make_premis_uuid($eventtype,$capture_date);
    my $event = new PREMIS::Event($eventid, 'UUID', $eventtype, $capture_date, $detail);

    # Hardcoded agent ID for capture for Yale..
    $event->add_linking_agent(new PREMIS::LinkingAgent("HathiTrust AgentID","Kirtas",'Executor'));
    # get the first processingSoftwareName and Version, if it exists -- the JPG
    # MIX data won't have it but the JP2 will.
    my $mets_xc = $volume->get_yale_mets_xpc();
    my $capture_tool = $mets_xc->findvalue(
	'concat(/descendant::mix:processingSoftwareName[1]," ",/descendant::mix:processingSoftwareVersion[1])'
    );
    if ( defined $capture_tool and $capture_tool and $capture_tool !~ /^\s*$/ ) {
        $event->add_linking_agent(
            new PREMIS::LinkingAgent( "tool", $capture_tool, "image capture" )
        );
    }

    $premis->add_event($event);

}

sub _add_struct_map {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();

    my $mets_xc = $volume->get_yale_mets_xpc();
    # create map from file IDs in provided Yale METS to our IDs

    # Generate maps needed to create new structmap:
    #   Map from old Yale METS file ID => filename
    my %files_by_yalefileid;

    foreach my $file ( $mets_xc->findnodes('//mets:file') ) {

   # Determine the filename by which we will refer to this file in the new METS.
        my $oldname = $mets_xc->findvalue('./mets:FLocat/@xlink:href',$file);
        $oldname =~ /^.*\\([^\\]+)$/;
        my $newname = $1;
        $newname =~ tr/[A-Z]/[a-z]/;
        $newname =~ s/jpg$/jp2/;
        $newname =~ s/_alto//;

	my $yale_fileid = $file->findvalue('./@ID');

	$self->set_error("MissingField",field => 'ID',
	    file=>$oldname,detail=>'Missing @ID on mets:FLocat')
	    unless defined $yale_fileid and $yale_fileid;

        $files_by_yalefileid{$yale_fileid} = $newname;

    }

    # Generate maps needed to create new structmap
    #   Map from filename => other files in page for structmap
    #   (The Yale METS doesn't always include the XML in the structmap, so we
    #   just use a single file from the Yale structMap to find the appopriate
    #   page)
    my %pagefiles_by_file;
    foreach my $page (values( %{ $volume->get_file_groups_by_page() })) {
	my $thispage_files = [];
	foreach my $fgrp (values (%$page)) {
	    foreach my $file (@$fgrp) {
		push(@$thispage_files,$file);
		$pagefiles_by_file{$file} = $thispage_files;
	    }
	}
    }



    # Generate maps needed to create new structmap:
    #   Map from filename => new file IDs to use in METS

    my %new_fileids;

    my $vol_filegroups = $volume->get_file_groups();
    while(my ($fgid, $fgroup) = each (%$vol_filegroups)) {
	my $mets_fgroup = $self->{filegroups}{$fgid};
	if(not defined $mets_fgroup) {
	    $self->set_error("BadFilegroup",detail=>"METS file group $fgid missing");
	    next;
	}
        foreach my $file ( @{ $fgroup->get_filenames() } ) {
            my $fileid = $mets_fgroup->get_file_id($file);
            $new_fileids{ $file } = $fileid
        }

    }

    # migrate structmaps
    foreach my $structmap_type (qw(logical physical)) {
        my $structmap =
          $mets_xc->find(qq(//mets:structMap[\@TYPE="$structmap_type"]))->[0];
        foreach my $fp_div (
            $structmap->findnodes('.//mets:div[mets:fptr[@FILEID]]') )
        {
            my $yale_fileid = $fp_div->findvalue('./mets:fptr[1]/@FILEID');

            # remove any existing children and add all three filegrp children
            $fp_div->removeChildNodes();

            my $filename = $files_by_yalefileid{$yale_fileid};
	    if(not defined $filename) {
		$self->set_error("BadFilename",file=>$filename,detail=>"Can't find file in Yale fileSec");
		next;
	    }

	    my $thispage_files = $pagefiles_by_file{$filename};
	    if(not defined $thispage_files) {
		$self->set_error("BadFilename",file=>$filename,detail=>"Can't find file in any filegroup");
		next;
	    }

	    foreach my $pagefile (@$thispage_files) {
		my $new_fileid = $new_fileids{$pagefile};
		if(not defined $new_fileid) {
		    $self->set_error("BadFilename",file=>$pagefile,detail=>"Can't find file ID");
		    next;
		}
                $fp_div->appendChild(
                    METS::createElement(
                        'fptr', { FILEID => "$new_fileid" }
                    )
                );
	    }
        }

        $mets->add_struct_map($structmap);
    }


}

=item _add_dmd_sec($mets,$id,$type,$desc,$path)

Extracts a metadata section from Yale METS (if it exists) or creates a new
one from an XML file on the filesystem. Returns true if an appropriate metadata
section was found and false if it does not.

=cut

sub _add_dmd_sec {
    my $self = shift;

    my $mdsec = $self->_metadata_section( "dmdSec", @_ );
    $self->{mets}->add_dmd_sec($mdsec) if defined $mdsec;
}

=item _metadata_section($sectype,$id,$type,$desc,$path)

Extracts a metadata section from Yale METS (if it exists) or creates a new
one from an XML file on the filesystem. Returns the METS::MetadataSection
object if an appropriate metadata section was found and undef if it does not.

=cut

sub _metadata_section {

    my $self = shift;
    my $mets_xc = $self->{volume}->get_yale_mets_xpc();

    # TODO: validate sections
    my $sectype = shift;
    my $id      = shift;
    my $type    = shift;
    my $desc    = shift;
    my $path    = shift;

    my %attrs = (
        mdtype => $type,
        label  => $desc
    );

    my $mdsec = new METS::MetadataSection( $sectype, 'id' => $id );
    my $mdsec_nodes = $mets_xc->find(
        qq(//mets:$sectype/mets:mdWrap[\@MDTYPE="$type"]/mets:xmlData));

    # FIXME: get child of node and use that as node
    if ( $mdsec_nodes->size() ) {
        $self->set_error('BadFile',detail => "Multiple $type mdsecs found") if ( $mdsec_nodes->size() > 1 );
        my $childnode = $mdsec_nodes->get_node(0)->firstChild();
        $mdsec->set_data( $childnode, %attrs );
        return $mdsec;
    }
    elsif ( -e $path ) {
        $mdsec->set_xml_file( $path, %attrs );
        return $mdsec;
    }

    return undef;
}

# Override base class: just add content FGs
sub _add_filesecs {
    my $self   = shift;

    $self->_add_content_fgs();

}

sub clean_always{
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
    my $mets_path = "$stage_path/Yale_" . $objid . ".xml";

    unlink($mets_path);
}

1;
