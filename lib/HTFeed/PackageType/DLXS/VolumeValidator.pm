#!/usr/bin/perl

package HTFeed::PackageType::DLXS::VolumeValidator;

use base qw(HTFeed::VolumeValidator);

use strict;

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    $self->{stages}{validate_consistency} =  \&_validate_consistency;

    return $self;

}

sub _validate_consistency {
    my $self   = shift;
    $self->SUPER::_validate_consistency(@_);

    my $volume = $self->{volume};

    my $files = $volume->get_required_file_groups_by_page();

    # TODO: extract allowed missing sequence numbers from PREMIS event.
    # OR RENUMBER??
    
    # Make sure there are no gaps in the sequence except for those
    # allowed by PREMIS events.

    # Make sure that every jp2 has a corresponding TIFF.
    while ( my ( $sequence_number, $files ) = each( %{$files} ) ) {
        my $has_jp2 = 0;
        my $has_tif = 0;
        foreach my $file (@{$files->{image}}) {
            $has_jp2++ if($file =~ /\.jp2$/);
            $has_tif++ if($file =~ /\.tif$/);
        }
        if($has_jp2 and !$has_tif) {
            $self->set_error("MissingFile",file => "$sequence_number.tif",
                detail => "JP2 for seq=$sequence_number exists but TIFF does not.")
        }
    }
}


1;
