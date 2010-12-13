package HTFeed::ImageRemediate;

use strict;
use warnings;
use HTFeed::Config qw(get_config);


=item get_exiftool_fields($file)

    Returns a hash of all the tags found by ExifTool in the specified file.
    The keys are in the format GroupName:TagName in the same format as the
    tag names returned by exiftool -X $file

=cut

sub get_exiftool_fields {
    require Image::ExifTool;

    my $file   = shift;
    my $fields = {};

    my $exifTool = new Image::ExifTool;
    $exifTool->ExtractInfo( $file, { Binary => 1 } );

    foreach my $tag ( $exifTool->GetFoundTags() ) {

        # get only the groupname we'll use to update it later
        my $group = $exifTool->GetGroup( $tag, "1" );
        my $tagname = Image::ExifTool::GetTagName($tag);
        $fields->{"$group:$tagname"} = $exifTool->GetValue($tag);
    }

    return $fields;
}

=item remediate_image($oldfile,$newfile,$force_headers,$set_if_undefined_headers)

    Prevalidates and remediates the image headers in $oldfile and writes the results as $newfile.

    $force_headers and $set_if_undefined_headers are references to hashes:
	{ header => $value, 
	  header2 => $value, ...}

    Additional parameters can be passed to set the value for particular fields.
    $force_headers lists headers to force whether or not they are present, and
    $set_if_undefined_heaeders gives headers to set if they are not already
    defined.

    For example,

    remediate_image($oldfile,$newfile,['XMP-dc:source' => 'Internet Archive'],['XMP-tiff:Make' => 'Canon'])

    will force the XMP-dc:source field to 'Internet Archive' whether or not it is already present,
    and set XMP-tiff:Make to Canon if XMP-tiff:Make is not otherwise defined.

    The special header 'Resolution' can be set to set X/Y resolution related fields; it should be 
    specified in pixels per inch.

=cut

sub remediate_image($$;$$) {
    my $infile                   = shift;
    my $outfile                  = shift;
    my $force_headers            = ( shift or {} );
    my $set_if_undefined_headers = shift;

    my $newFields = $force_headers;
    my $oldFields = get_exiftool_fields($infile);

    # Jpeg2000:ImageWidth -> XMP-tiff:ImageWidth
    _copy_old_to_new( $oldFields->{'Jpeg2000:ImageWidth'},
        $newFields, 'XMP-tiff:ImageWidth' );

    # Jpeg2000:ImageHeight -> XMP-tiff:ImageHeight
    _copy_old_to_new( $oldFields->{'Jpeg2000:ImageHeight'},
        $newFields, 'XMP-tiff:ImageHeight' );

    # Jpeg2000:Compression -> XMP-tiff:Compression
    _copy_old_to_new( $oldFields->{'Jpeg2000:Compression'},
        $newFields, 'XMP-tiff:Compression' );

    # IFD0:Make -> XMP-tiff:Make
    _copy_old_to_new( $oldFields->{'IFD0:Make'}, $newFields, 'XMP-tiff:Make' );

    # IFD0:Model -> XMP-tiff:Model
    _copy_old_to_new( $oldFields->{'IFD0:Model'}, $newFields,
        'XMP-tiff:Model' );

    # For IA, Colorspace should always be sRGB. Only set these fields if they
    # aren't already defined.
    if ( $oldFields->{'Jpeg2000:Colorspace'} eq 'sRGB' ) {
        _set_new_if_undefined( $oldFields, $newFields, 'XMP-tiff:BitsPerSample',
            '8, 8, 8' );
        _set_new_if_undefined( $oldFields, $newFields,
            'XMP-tiff:PhotometricInterpretation', 'RGB' );
        _set_new_if_undefined( $oldFields, $newFields,
            'XMP-tiff:SamplesPerPixel', '3' );
    }

    # Other package types may have grayscale JP2s that need remediation.
    # Final image validation should kick these out if grayscale is not 
    # expected.
    if ( $oldFields->{'Jpeg2000:Colorspace'} eq 'Grayscale' ) {
        _set_new_if_undefined( $oldFields, $newFields, 'XMP-tiff:BitsPerSample',
            '8' );
        _set_new_if_undefined( $oldFields, $newFields,
            'XMP-tiff:PhotometricInterpretation', 'BlackIsZero' );
        _set_new_if_undefined( $oldFields, $newFields,
            'XMP-tiff:SamplesPerPixel', '1' );
    }

    # Orientation should always be normal
    _set_new_if_undefined( $oldFields, $newFields, 'XMP-tiff:Orientation',
        'Horizontal (normal)' );

    # Force dc:source even if it was already defined
    # $newFields->{'XMP-dc:Source'}   = "$ark_id/$image_file";
    # $newFields->{'XMP-tiff:Artist'} = "Internet Archive";

    my $resolution = undef;

    # try to get resolution from JPEG2000 headers
    if(!$force_headers->{'Resolution'})  {
	my $xres = $oldFields->{'Jpeg2000:CaptureXResolution'};
	my $yres = $oldFields->{'Jpeg2000:CaptureYResolution'};
	warn ("Non-square pixels??! XRes $xres YRes $yres") if( ($xres or $yres) and $xres != $yres);

	if($xres) {
	    my $xresunit = $oldFields->{'Jpeg2000:CaptureXResolutionUnit'};
	    my $yresunit = $oldFields->{'Jpeg2000:CaptureXResolutionUnit'};

	    warn("Resolution unit awry") if (not $xresunit or not $yresunit or $xresunit ne $yresunit);

	    $xresunit eq 'um' and $force_headers->{'Resolution'} = sprintf("%.0f",$xres*25400);
	    $xresunit eq 'mm' and $force_headers->{'Resolution'} = sprintf("%.0f",$xres*25.4);
	    $xresunit eq 'cm' and $force_headers->{'Resolution'} = sprintf("%.0f",$xres*2.54);
	    $xresunit eq 'in' and $force_headers->{'Resolution'} = sprintf("%.0f",$xres);
	}

    }


    my $force_res  = 0;
    if (
        (
            defined( $resolution = $force_headers->{'Resolution'} )
            && ($force_res = 1)
        )    # force resolution change if field is set in $force_headers
        or defined( $resolution = $set_if_undefined_headers->{'Resolution'} )
      )
    {
        if ($force_res) {
            $newFields->{'XMP-tiff:XResolution'}    = $resolution;
            $newFields->{'XMP-tiff:YResolution'}    = $resolution;
            $newFields->{'XMP-tiff:ResolutionUnit'} = 'inches';
        }
        else {
            _set_new_if_undefined( $oldFields, $newFields,
                'XMP-tiff:XResolution', $resolution );
            _set_new_if_undefined( $oldFields, $newFields,
                'XMP-tiff:YResolution', $resolution );
            _set_new_if_undefined( $oldFields, $newFields,
                'XMP-tiff:ResolutionUnit', 'inches' );

        }

        # Overwrite IFD0:XResolution/IFD0:YResolution if they are present
        if ( defined $oldFields->{'IFD0:XResolution'} ) {
            $newFields->{'IFD0:XResolution'} = $resolution;
            $newFields->{'IFD0:YResolution'} = $resolution;
        }
    }

    my $exifTool = new Image::ExifTool;
    while ( my ( $field, $val ) = each(%$newFields) ) {
        my ( $success, $errStr ) = $exifTool->SetNewValue( $field, $val );
        if ( defined $errStr ) {
            warn("Error setting new tag $field => $val: $errStr\n");
        }
    }

    my $kdu_munge = get_config('kdu_munge');
    system( "$kdu_munge -i $infile -o $outfile 2>&1 > /dev/null");

    if ( !$exifTool->WriteInfo($outfile) ) {
        die(   "Couldn't update JPEG2000 tags for $outfile: "
              . $exifTool->GetValue('Error')
              . "\n" );
    }

}

=item _copy_old_to_new($oldValue, $newFields, $newFieldName)

Copies old field value to the new field value, but only if the old value is defined
and the new one isn't.

=cut 

sub _copy_old_to_new($$$) {
    my ( $oldValue, $newFields, $newFieldName ) = @_;

    if ( defined $oldValue
        and not defined $newFields->{$newFieldName} )
    {
        $newFields->{$newFieldName} = $oldValue;
    }
}

=item _set_new_if_undefined($oldFields,$newFields,$newFieldName,$newFieldVal)

Copies old field value to the new field value, but only if the old value is defined
and the new one isn't.

=cut 

sub _set_new_if_undefined($$$$) {
    my ( $oldFields, $newFields, $newFieldName, $newFieldVal ) = @_;

    if ( not defined $oldFields->{$newFieldName} ) {
        $newFields->{$newFieldName} = $newFieldVal;
    }
}

1;
