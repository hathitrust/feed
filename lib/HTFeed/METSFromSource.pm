#!/usr/bin/perl

package HTFeed::METSFromSource;
use HTFeed::METS;
use base qw(HTFeed::METS);

# Copy structmaps and fileSecs directly from source METS, but
# remove any DMDsecs referenced for individual files with extraneous
# metadata that will not be present in the HT METS.

sub _add_struct_map {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    # Import the source structMap as it is
    my $src_mets_xpc   = $volume->get_source_mets_xpc();
    my @src_mets_nodes = $src_mets_xpc->findnodes("//mets:structMap");
    if ( @src_mets_nodes == 1 ) {
        $mets->add_struct_map( $src_mets_nodes[0] );
    }
    elsif ( !@src_mets_node ) {
        $self->set_error(
            "MissingField",
            file        => $volume->get_source_mets_file(),
            fileid      => 'mets:structMap',
            description => "Can't find structMap in source METS"
        );
    }
    else {
        my $count = scalar(@src_mets_node);
        $self->set_error(
            "BadField",
            file        => $volume->get_source_mets_file(),
            fileid      => 'mets:structMap',
            description => '$count structMaps found in source METS'
        );
    }

}

# Import the source fileSecs as they are, preserving the SEQ for any
# out-of-order files or partial OCR, but omit the AMDIDs and DMDIDs since the
# per-file metadata isn't brought in.
sub _add_content_fgs {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $src_mets_xpc  = $volume->get_source_mets_xpc();
    my @filegrp_nodes = $src_mets_xpc->findnodes("//mets:fileGrp");
    foreach my $filegrp_node (@filegrp_nodes) {
        foreach my $file_node ( $src_mets_xpc->findnodes( "./mets:file", $filegrp_node ) ) {
            $file_node->removeAttribute('DMDID');
            $file_node->removeAttribute('ADMID');
        }
        my $filegrp_id = $self->_get_subsec_id("FG");
        $filegrp_node->setAttribute( "ID", $filegrp_id );
        $mets->add_filegroup($filegrp_node);
    }
}

1;

__END__
