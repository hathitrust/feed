#!/usr/bin/perl

package HTFeed::PackageType::MDLContone::METS;
use base qw(HTFeed::METS);

sub _add_struct_map {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $struct_map = new METS::StructMap( id => 'SM1', type => 'physical' );
    my $voldiv = new METS::StructMap::Div( type => 'item' );
    $struct_map->add_div($voldiv);
    my $order               = 1;

    # MDL contone image will have only the image file group, and there's no associated sequence
    my $image_file_group = $volume->get_file_groups()->{'image'};
    foreach my $file ($image_file_group->get_files()) {
	my $fileid = $self->{filegroups}{$filegroup_name}->get_file_id($file);
	croak("Can't find file ID for $file in $filegroup_name")
	  unless defined $fileid;

	push( @$pagediv_ids, $fileid );

        $voldiv->add_file_div(
            $pagediv_ids,
            order => $order++,
            type  => 'image',
        );
    }
    $mets->add_struct_map($struct_map);

}
1;
