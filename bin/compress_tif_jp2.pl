#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Stage::ImageRemediate;
use HTFeed::TestVolume;
use HTFeed::Config qw(get_config);
use List::Util qw(max);
use POSIX qw(ceil);

# This script shows how to compress TIFF to JPEG2000 images and add an XMP
# using kakadu and exiftool. Feel free to modify to your own needs.


my $self = new HTFeed::Stage::ImageRemediate(volume => new HTFeed::TestVolume(namespace => 'namespace', packagetype => 'pkgtype')); 


foreach my $infile (@ARGV) {
    die("$infile does not exist") if !-e $infile;
    # reset remediator;

    $self->{newFields} = {};
    $self->{oldFields} = {};
    my $outfile = $infile;
    $outfile =~ s/\.tif$/.jp2/;
    my ($field,$val);

    # first read old fields; we need the length to set levels properly
    $self->{oldFields} = $self->get_exiftool_fields($infile);

    # From Roger:
    #
    # $levels would be derived from the largest dimension:
    #
    # - 0     < x <= 6400  : nlev=5
    # - 6400  < x <= 12800 : nlev=6
    # - 12800 < x <= 25600 : nlev=7
    my $maxdim = max($self->{oldFields}->{'IFD0:ImageWidth'},
        $self->{oldFields}->{'IFD0:ImageHeight'});
    my $levels = max(5,ceil(log($maxdim/100)/log(2)) - 1);

    # try to compress the TIFF -> JPEG2000
    print("Compressing $infile to $outfile\n");
    my $kdu_compress = get_config('kdu_compress');
    die("You must correctly configure the path to kdu_compress in the feed configuration\n") 
    if not defined $kdu_compress or !-x $kdu_compress;

    # Settings for kdu_compress recommended from Roger Espinosa. "-slope"
    # is a VBR compression mode; the value of 42988 corresponds to pre-6.4
    # slope of 51180, the current (as of 5/6/2011) recommended setting for
    # Google digifeeds.
    system(qq($kdu_compress -quiet -i '$infile' -o '$outfile' Clevels=$levels Clayers=8 Corder=RLCP Cuse_sop=yes Cuse_eph=yes "Cmodes=RESET|RESTART|CAUSAL|ERTERM|SEGMARK" -no_weights -slope 42988))

        and die("kdu_compress returned $?");

    # then set new metadata fields: copy from exiftool field called
    # IFD0:whatever to XMP-tiff:whatever, where the fields have the same name
    foreach $field  ( qw(ImageWidth ImageHeight BitsPerSample 
        PhotometricInterpretation Orientation 
        SamplesPerPixel XResolution YResolution 
        ResolutionUnit Artist Make Model) ) {
        $self->copy_old_to_new("IFD0:$field","XMP-tiff:$field");
    }

    # Copy IFD0:Modifydate to XMP-tiff:DateTime
    $self->copy_old_to_new("IFD0:ModifyDate","XMP-tiff:DateTime");
    my $docname = $self->{oldFields}->{'IFD0:DocumentName'};

    # Migrate the DocumentName field to the XMP dc:source field, updating
    # the extension
    if(defined $docname) {
        $docname =~ s/\.tif$/\.jp2/;
        $self->set_new_if_undefined("XMP-dc:source",$docname);
    }

    # Set the XMP-tiff:Compression header to JPEG 2000
    $self->set_new_if_undefined("XMP-tiff:Compression","JPEG 2000");

    # Actually do the work of setting the fields with ExifTool
    my $exifTool = new Image::ExifTool;
    while ( ( $field, $val ) = each(%{$self->{newFields}}) ) {
        my ( $success, $errStr ) = $exifTool->SetNewValue( $field, $val );
        if ( defined $errStr ) {
            croak("Error setting new tag $field => $val: $errStr\n");
        }
    }

    $self->update_tags($exifTool,"$outfile");
}

