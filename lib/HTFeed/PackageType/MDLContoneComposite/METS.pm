#!/usr/bin/perl

package HTFeed::PackageType::MDLContoneComposite::METS;
use HTFeed::PackageType::MDLContone::METS;
use base qw(HTFeed::PackageType::MDLContone::METS);

sub _add_struct_map {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    # Import the source structMap as it is
    my $src_mets_xpc = $volume->get_source_mets_xpc();
    my @src_mets_nodes = $src_mets_xpc->findnodes("//mets:structMap");
    if(@src_mets_nodes == 1) {
	$mets->add_struct_map($src_mets_nodes[0]);
    } elsif (!@src_mets_node) {
	$self->set_error("MissingField",file => $volume->get_source_mets_file(),fileid => 'mets:structMap',description => "Can't find structMap in source METS");
    } else {
	my $count = scalar(@src_mets_node);
	$self->set_error("BadField",file=> $volume->get_source_mets_file(),fileid => 'mets:structMap',description => '$count structMaps found in source METS');
    }

}

sub _add_content_fgs {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    # Import the source fileSecs as they are, preserving the SEQ for any
    # out-of-order files or partial OCR, but omit the DMDIDs since the
    # per-image DC isn't being brought in
    my $src_mets_xpc = $volume->get_source_mets_xpc();
    my @filegrp_nodes = $src_mets_xpc->findnodes("//mets:fileGrp");
    foreach my $filegrp_node (@filegrp_nodes) {
	foreach my $file_node ($src_mets_xpc->findnodes("./file",$filegrp_node)) {
	    $file_node->removeAttribute('DMDID');
	}
	my $filegrp_id = $self->_get_subsec_id("FG");
	$filegrp_node->setAttribute("ID",$filegrp_id);
	$mets->add_filegroup($filegrp_node);
    }
}
1;
