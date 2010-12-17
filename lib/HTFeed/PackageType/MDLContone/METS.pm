#!/usr/bin/perl

package HTFeed::PackageType::MDLContone::METS;
use base qw(HTFeed::METS);
use strict;

sub _add_struct_map {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $struct_map = new METS::StructMap( id => 'SM1', type => 'physical' );
    my $voldiv = new METS::StructMap::Div( type => 'item' );
    $struct_map->add_div($voldiv);
    my $order               = 1;

    # MDL contone image will have only the image file group, and there's no associated sequence
    my $filegroup_name = 'image';
    my $image_file_group = $volume->get_file_groups()->{$filegroup_name};
    foreach my $file ( @{ $image_file_group->get_filenames() }) {
        my $fileid = $self->{filegroups}{$filegroup_name}->get_file_id($file);
        croak("Can't find file ID for $file in $filegroup_name")
        unless defined $fileid;

        $voldiv->add_file_div(
            [$fileid],
            order => $order++,
            type  => 'image',
        );
    }
    $mets->add_struct_map($struct_map);

}

sub _add_dmdsecs {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $src_mets_xpc = $volume->get_source_mets_xpc();
    my @dmd_nodes = $src_mets_xpc->findnodes(q( //mets:dmdSec[@ID='DMD1'][mets:mdWrap[@MDTYPE='DC'][@LABEL='MDL metadata']] ));
    if(@dmd_nodes == 1) {
        $mets->add_dmd_sec($dmd_nodes[0]);
    } elsif (!@dmd_nodes) {
        $self->set_error("MissingField",file => $volume->get_source_mets_file(),field => 'mets:dmdSec',detail=> "Can't find DMD1 DC dmdSec in source METS");
    } else {
        my $count = scalar(@dmd_nodes);
        $self->set_error("BadField",file=> $volume->get_source_mets_file(),field => 'mets:structMap',detail=> '$count DMD1 DC dmdSecs found in source METS');
    }
    # MIU: add TEIHDR; do not add second call number??
}
1;
