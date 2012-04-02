#!/usr/bin/perl

package HTFeed::PackageType::Kirtas::SourceMETS;
use strict;
use warnings;
use HTFeed::SourceMETS;
use base qw(HTFeed::SourceMETS);
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);

sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
        @_,

    );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    $self->{outfile} = "$stage_path/Kirtas_" . $pt_objid . ".xml";

    return $self;
}


sub _add_dmdsecs {
    my $self   = shift;
    my $volume = $self->{volume};
    my $mets   = $self->{mets};
    my $objid = $volume->get_objid();

    my $preingest_dir = $volume->get_preingest_directory();
    my $metadata_dir = "$preingest_dir/metadata";

    my $marc_mdsec = $self->_add_dmd_sec(
        $self->_get_subsec_id("DMD"), 'MARC',
        'Institution MARC record',
        "$metadata_dir/${objid}_mrc.xml"
    );

    # get & remediate the marc data
    my $marc_node = ($marc_mdsec->{mdwrap}->getElementsByTagNameNS(NS_MARC,'record'))[0];
    my $marc_xc = new XML::LibXML::XPathContext($marc_node);
    register_namespaces($marc_xc);
    $self->_remediate_marc($marc_xc);

    my $mods_dmdsec = $self->_add_dmd_sec(
        $self->_get_subsec_id("DMD"), 'MODS',
        'MODS metadata',
        "$metadata_dir/${objid}_mods.xml"
    );

    # try to fix up schema reference for MODS

    my $mods_xc = new XML::LibXML::XPathContext($mods_dmdsec->{'mdwrap'});
    register_namespaces($mods_xc);
    foreach my $mods ($mods_xc->findnodes('.//mods:mods'), $mods_xc->findnodes('.//mods:modsCollection')) {
        my $schema = $mods->getAttribute('xsi:schemaLocation');
        # force use of latest MODS schema
        if(defined $schema) {
            $schema =~ s/mods-3-[01234].xsd/mods.xsd/; 
            $mods->setAttribute('xsi:schemaLocation',$schema);
        }
    }

    $self->_add_dmd_sec(
        $self->_get_subsec_id("DMD"), 'DC',
        'OAI/DC metadata',
        "$metadata_dir/${objid}_oaidc.xml"
    );

}

sub _add_techmds {
    my $self = shift;
    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $preingest_dir = $volume->get_preingest_directory();
    my $metadata_dir = "$preingest_dir/metadata";

    my $scanjob_sec = $self->_metadata_section(
        'techMD',
        'TM_ScanJob',
        'OTHER',
        'Technical metadata generated by Kirtas APT Manager and BookScan Editor',
        "$metadata_dir/${objid}_scanjob.xml"
    );
    push(@{ $self->{amd_mdsecs} },$scanjob_sec);

}


sub _add_capture_event {
    my $self = shift;
    my $premis = $self->{premis};
    my $volume = $self->{volume};
    # Add the custom capture event, extracting info from the Kirtas METS
    my $eventcode = 'capture';
    my $eventconfig = $volume->get_nspkg()->get_event_configuration($eventcode);
    $eventconfig->{'executor'} = 'Kirtas';
    $eventconfig->{'executor_type'} = 'HathiTrust AgentID';
    $eventconfig->{'date'} = $volume->get_capture_time();
    $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$eventconfig->{'date'});
    my $event = $self->add_premis_event($eventconfig);

    # get the first processingSoftwareName and Version, if it exists -- the JPG
    # MIX data won't have it but the JP2 will.
    my $mets_xc = $volume->get_kirtas_mets_xpc();
    my $capture_tool = $mets_xc->findvalue(
        'concat(/descendant::mix:processingSoftwareName[1]," ",/descendant::mix:processingSoftwareVersion[1])'
    );
    if ( defined $capture_tool and $capture_tool and $capture_tool !~ /^\s*$/ ) {
        $event->add_linking_agent(
            new PREMIS::LinkingAgent( "tool", $capture_tool, "image capture" )
        );
    }


}

sub _add_struct_map {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();

    my $mets_xc = $volume->get_kirtas_mets_xpc();
    # create map from file IDs in provided Kirtas METS to our IDs

    # Generate maps needed to create new structmap:
    #   Map from old Kirtas METS file ID => filename
    my %files_by_kirtasfileid;

    foreach my $file ( $mets_xc->findnodes('//mets:file') ) {

        # Determine the filename by which we will refer to this file in the new METS.
        my $oldname = $mets_xc->findvalue('./mets:FLocat/@xlink:href',$file);
        $oldname =~ /^.*\\([^\\]+)$/;
        my $newname = $1;
        $newname =~ tr/[A-Z]/[a-z]/;
        $newname =~ s/jpg$/jp2/;
        $newname =~ s/_alto//;

        my $kirtas_fileid = $file->findvalue('./@ID');

        $self->set_error("MissingField",field => 'ID',
            file=>$oldname,detail=>'Missing @ID on mets:FLocat')
        unless defined $kirtas_fileid and $kirtas_fileid;

        $files_by_kirtasfileid{$kirtas_fileid} = $newname;

    }

    # Generate maps needed to create new structmap
    #   Map from filename => other files in page for structmap
    #   (The Kirtas METS doesn't always include the XML in the structmap, so we
    #   just use a single file from the Kirtas structMap to find the appopriate
    #   page)
    my %pagefiles_by_file;
    foreach my $page (values( %{ $volume->get_structmap_file_groups_by_page() })) {
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
            my $kirtas_fileid = $fp_div->findvalue('./mets:fptr[1]/@FILEID');

            # remove any existing children and add all three filegrp children
            $fp_div->removeChildNodes();

            my $filename = $files_by_kirtasfileid{$kirtas_fileid};
            if(not defined $filename) {
                $self->set_error("BadFilename",file=>$filename,detail=>"Can't find file in Kirtas fileSec");
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

Extracts a metadata section from Kirtas METS (if it exists) or creates a new
one from an XML file on the filesystem. Returns true if an appropriate metadata
section was found and false if it does not.

=cut

sub _add_dmd_sec {
    my $self = shift;

    my $mdsec = $self->_metadata_section( "dmdSec", @_ );
    $self->{mets}->add_dmd_sec($mdsec) if defined $mdsec;
    return $mdsec;
}

=item _metadata_section($sectype,$id,$type,$desc,$path)

Extracts a metadata section from Kirtas METS (if it exists) or creates a new
one from an XML file on the filesystem. Returns the METS::MetadataSection
object if an appropriate metadata section was found and undef if it does not.

=cut

sub _metadata_section {

    my $self = shift;
    my $mets_xc = $self->{volume}->get_kirtas_mets_xpc();

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


1;
