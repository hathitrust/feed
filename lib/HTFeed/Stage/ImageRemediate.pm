package HTFeed::Stage::ImageRemediate;

use strict;
use warnings;
use base qw(HTFeed::Stage::JHOVE_Runner);
use List::Util qw(max min);
use POSIX qw(ceil);
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use File::Copy;
use Carp;
use HTFeed::XMLNamespaces qw(register_namespaces);
use Encode qw(decode);
use File::Basename qw(basename);

=head1 NAME

HTFeed::Stage::ImageRemediate - Image file processing

=head1 DESCRIPTION

ImageRemediate.pm is the main class for image file remediation.
The class provides methods for cleaning up image files prior to ingest.

=cut

sub run {
    die("Subclass must implement run.");
}

=item get_exiftool_fields()

Returns a hash of all the tags found by ExifTool in the specified file.
The keys are in the format GroupName:TagName in the same format as the
tag names returned by exiftool -X $file

$fields_ref = get_exiftool_fields($file)

=cut

sub get_exiftool_fields {
    require Image::ExifTool;

    my $self   = shift;
    my $file   = shift;
    my $fields = {};

    my $exifTool = new Image::ExifTool;
    # if it can't make a valid file jhove will complain later
    $exifTool->Options('IgnoreMinorErrors' => 1);
    $exifTool->Options('ScanForXMP' => 1);
    $exifTool->ExtractInfo( $file, { Binary => 1 } );

    foreach my $tag ( $exifTool->GetFoundTags() ) {

        # get only the groupname we'll use to update it later
        my $group = $exifTool->GetGroup( $tag, "1" );
        my $tagname = Image::ExifTool::GetTagName($tag);
        $fields->{"$group:$tagname"} = $exifTool->GetValue($tag);
    }

    return $fields;
}

=item remediate_image()

Prevalidates and remediates the image headers in $oldfile and writes the results as $newfile.

usage: $self->remediate_image($oldfile,$newfile,$force_headers,$set_if_undefined_headers)

$force_headers and $set_if_undefined_headers are references to hashes:
{ header => $value, 
header2 => $value, ...}

Additional parameters can be passed to set the value for particular fields.
$force_headers lists headers to force whether or not they are present, and
$set_if_undefined_heaeders gives headers to set if they are not already
defined.

For example,

remediate_jpeg2000($oldfile,$newfile,['XMP-dc:source' => 'Internet Archive'],['XMP-tiff:Make' => 'Canon'])

will force the XMP-dc:source field to 'Internet Archive' whether or not it is already present,
and set XMP-tiff:Make to Canon if XMP-tiff:Make is not otherwise defined.

The special header 'Resolution' can be set to set X/Y resolution related fields; it should be 
specified in pixels per inch.

=cut

sub remediate_image {
    my $self    = shift;
    my $oldfile = shift;

    # dispatch to appropriate remediator
    return $self->_remediate_jpeg2000( $oldfile, @_ )
      if ( $oldfile =~ /\.jp2$/ );
    return $self->_remediate_tiff( $oldfile, @_ ) if ( $oldfile =~ /\.tif$/ );

    # something else..
    $self->set_error(
        "BadFile",
        file   => $oldfile,
        detail => "Unknown image format; can't remediate"
    );
}

=item update_tags()

Updates the tags in outfile with the parameters set in the given exiftool

$self->update_tags($exifTool,$outfile);

=cut

sub update_tags {
    my $self     = shift;
    my $exifTool = shift;
    my $outfile  = shift;
    my $infile   = shift;

    my $res;

    if ( defined $infile ) {
        $res = $exifTool->WriteInfo( $infile, $outfile );
    }
    else {
        $res = $exifTool->WriteInfo($outfile);
    }

    if ( !$res ) {
        $self->set_error(
            "OperationFailed",
            operation => "exiftool write",
            file      => "$outfile",
            detail    => $exifTool->GetValue('Error')
        );
    }
}

=item copy_old_to_new()

Copies old field value to the new field value, but only if the old value is defined
and the new one isn't.

$self->copy_old_to_new($oldFieldName, $newFieldName);

=cut

sub copy_old_to_new($$$) {
    my $self = shift;
    my ( $oldFieldName, $newFieldName ) = @_;
    my $oldValue = $self->{oldFields}->{$oldFieldName};

    if ( defined $self->{oldFields}->{$oldFieldName}
        and not defined $self->{newFields}->{$newFieldName} )
    {
        $self->{newFields}->{$newFieldName} = $oldValue;
    }
}

=item set_new_if_undefined()

Copies old field value to the new field value, but only if the old value is defined
and the new one isn't.

$self->set_new_if_undefined($newFieldName,$newFieldVal);

=cut

sub set_new_if_undefined($$$) {
    my $self = shift;
    my ( $newFieldName, $newFieldVal ) = @_;

    if ( not defined $self->{oldFields}->{$newFieldName}
        or $self->{oldFields}->{$newFieldName} eq '' )
    {
        $self->{newFields}->{$newFieldName} = $newFieldVal;
    }
}

sub stage_info {
    return { success_state => 'images_remediated', failure_state => '' };
}

sub _remediate_tiff {
    my $self                     = shift;
    my $infile                   = shift;
    my $outfile                  = shift;
    my $force_headers            = ( shift or {} );
    my $set_if_undefined_headers = shift;

    my $bad                   = 0;
    my $remediate_imagemagick = 0;    #needs imagemagick fix
    $self->{newFields} = $force_headers;
    $self->{oldFields} = $self->get_exiftool_fields($infile);
    my $fields = $self->{oldFields};


    my $status = $self->{jhoveStatus};
    if ( not defined $status ) {
        croak(
"No Status field for $infile, not remediable (did JHOVE run properly?)\n"
        );
        $bad = 1;
    }
    elsif ( $status ne 'Well-Formed and valid' ) {
        foreach my $error ( @{ $self->{jhoveErrors} } ) {

            # Is the error remediable?
            my @exiftool_remediable_errs = (
                'IFD offset not word-aligned',
                'Value offset not word-aligned',
                'Tag 269 out of sequence',
                'Invalid DateTime separator',
                'Invalid DateTime digit',
                'Invalid DateTime length',
                'Count mismatch for tag 306', # DateTime -- fixable
                'Count mismatch for tag 36867' # EXIF DateTimeOriginal - ignorable

            );
            my @imagemagick_remediable_errs = ('PhotometricInterpretation not defined',
                                               'ColorSpace value out of range: 2',
                                              # wrong data type for tag - will get automatically stripped
                                               'Type mismatch for tag',
                                               # related to thumbnails, which imagemagick will strip
                                               'JPEGProc not defined for JPEG compression',
                                               'For PhotometricInterpretation, SamplesPerPixel must be >= 3, equals1',
                                               'For PhotometricInterpretation, SamplesPerPixel must be >= 1, equals: 1');
            if ( grep { $error =~ /^$_/ } @imagemagick_remediable_errs ) {
                get_logger()
                  ->trace(
"PREVALIDATE_REMEDIATE: $infile has remediable error '$error'\n"
                  );
                $remediate_imagemagick = 1;
            }
            elsif ( grep { $error =~ /^$_/ } @exiftool_remediable_errs ) {
                get_logger()
                  ->trace(
"PREVALIDATE_REMEDIATE: $infile has remediable error '$error'\n"
                  );
            }
            else {
                $self->set_error(
                    "BadFile",
                    file   => $infile,
                    detail => "Nonremediable error '$error'"
                );
                $bad = 1;
            }

        }

    }

    # Does it look like a contone? Bail & convert to JPEG2000 if so.
    if(!$bad and $fields->{'IFD0:BitsPerSample'} eq '8'
            or $fields->{'IFD0:SamplesPerPixel'} eq '3') {

        $infile = basename($infile);
        my ($seq) = ($infile =~ /^(.*).tif$/);
        return $self->convert_tiff_to_jpeg2000($seq);
        

    }

    if($self->{newFields}{DateTime}) {
      my $new_date = $self->{newFields}{DateTime};
      $self->set_new_date_fields($new_date,$new_date);
      delete $self->{newFields}{'DateTime'};
    } else {
      $self->fix_datetime($set_if_undefined_headers->{'DateTime'});
      delete $set_if_undefined_headers->{'DateTime'}
    }

    # Fix resolution, if needed
    my $force_res = $self->{newFields}{'Resolution'};
    if(defined($force_res)) {
        $self->{newFields}{'IFD0:ResolutionUnit'} = 'inch';
        $self->{newFields}{'IFD0:XResolution'} = $force_res;
        $self->{newFields}{'IFD0:YResolution'} = $force_res;
        delete $self->{newFields}{Resolution};
    }

# Prevalidate other fields -- don't bother checking unless there is not some other error

    if ( !$bad ) {
        $remediate_imagemagick = 1
          unless $self->prevalidate_field( 'IFD0:PhotometricInterpretation',
                  'WhiteIsZero', 1 );
        $remediate_imagemagick = 1
          unless $self->prevalidate_field( 'IFD0:Compression', 'T6/Group 4 Fax',
                  1 );
        if ( !$self->prevalidate_field( 'File:FileType', 'TIFF', 0 ) ) {
            $bad = 1;
            $self->set_error(
                "BadValue",
                field    => "File:FileType",
                actual   => $self->{oldFields}{'File:FileType'},
                expected => 'TIFF'
            );
        }
        if (
            !$self->prevalidate_field(
                'IFD0:Orientation', 'Horizontal (normal)', 1
            )
          )
        {
            $self->{newFields}{'IFD0:Orientation'} = 'Horizontal (normal)';
        }
        $remediate_imagemagick = 1
          unless $self->prevalidate_field( 'IFD0:BitsPerSample', '1', 0 );
        $remediate_imagemagick = 1
          unless $self->prevalidate_field( 'IFD0:SamplesPerPixel', '1', 0 );

    }



    my $ret = !$bad;

    if ( $remediate_imagemagick and !$bad ) {

        # return true if remediation succeeds
        $ret = $self->repair_tiff_imagemagick( $infile, $outfile );

        # repair the correct one when setting new headers
        $infile = $outfile;
    }

    while ( my ( $field, $val ) = each(%$set_if_undefined_headers) ) {
        $self->set_new_if_undefined( $field, $val );
    }

    # Fix the XMP, if needed
    if($self->needs_xmp) {
        # force required fields
        $self->{newFields}{'XMP-tiff:BitsPerSample'} = 1;
        $self->{newFields}{'XMP-tiff:Compression'} = 'T6/Group 4 Fax';
        $self->{newFields}{'XMP-tiff:PhotometricInterpretation'} = 'WhiteIsZero';
        $self->{newFields}{'XMP-tiff:Orientation'} = 'Horizontal (normal)';
        $self->{newFields}{'XMP-tiff:SamplesPerPixel'} = 1;
        $self->{newFields}{'XMP-tiff:ResolutionUnit'} = 1;
        $self->{newFields}{'XMP-tiff:ImageHeight'} = $self->{oldFields}{'IFD0:ImageHeight'};
        $self->{newFields}{'XMP-tiff:ImageWidth'} = $self->{oldFields}{'IFD0:ImageWidth'};

        # copy other fields; use new value if it was provided
        foreach my $field (qw(ResolutionUnit Artist XResolution YResolution Make Model)) {
          if(defined $self->{oldFields}{"IFD0:$field"}) {
            chomp($self->{oldFields}{"IFD0:$field"});
            $self->{newFields}{"IFD0:$field"} = $self->{oldFields}{"IFD0:$field"};
          } 
          
          if(defined $self->{newFields}{"IFD0:$field"}) {
            $self->{newFields}{"XMP-tiff:$field"} = $self->{newFields}{"IFD0:$field"};
          }
        }

        if(defined $self->{newFields}{"IFD0:DocumentName"}) {
            $self->{newFields}{"XMP-dc:source"} = $self->{newFields}{"IFD0:DocumentName"};
        } else {
            $self->{newFields}{"XMP-dc:source"} = $self->{oldFields}{"IFD0:DocumentName"};
        }

    }

    $ret = $ret
      && $self->repair_tiff_exiftool( $infile, $outfile, $self->{newFields} );

    return $ret;

}

sub repair_tiff_exiftool {
    my $self    = shift;
    my $infile  = shift;
    my $outfile = shift;
    my $fields  = shift;

    # fix the DateTime
    my $exifTool = new Image::ExifTool;
    $exifTool->Options('ScanForXMP' => 1);
    $exifTool->Options('IgnoreMinorErrors' => 1);
    while ( my ( $field, $val ) = each(%$fields) ) {
        my ( $success, $errStr ) = $exifTool->SetNewValue( $field, $val );
        if ( defined $errStr ) {
            croak("Error setting new tag $field => $val: $errStr\n");
            return 0;
        }
    }

    # make sure we have /something/ to write. All files should have
    # Orientation=normal, so this won't break anything.
    $exifTool->SetNewValue( "Orientation", "normal" );

    # whines if infile is same as outfile
    my @file_params = ($infile);
    push( @file_params, $outfile ) if ( $outfile ne $infile );

    if ( !$exifTool->WriteInfo(@file_params) ) {
        croak(  "Couldn't remediate $infile: "
              . $exifTool->GetValue('Error')
              . "\n" );
        return 0;
    }
}

sub repair_tiff_imagemagick {
    my $self    = shift;
    my $infile  = shift;
    my $outfile = shift;

    # try running IM on the TIFF file
    get_logger()
      ->trace("TIFF_REPAIR: attempting to repair $infile to $outfile\n");

    # convert returns 0 on success, 1 on failure
    my $imagemagick = get_config('imagemagick');
    my $rval = system("$imagemagick -compress Group4 '$infile' '$outfile' > /dev/null 2>&1");
    croak("failed repairing $infile\n") if $rval;

    return !$rval;

}

sub _remediate_jpeg2000 {
    my $self                     = shift;
    my $infile                   = shift;
    my $outfile                  = shift;
    my $force_headers            = ( shift or {} );
    my $set_if_undefined_headers = shift;

    $self->{newFields} = $force_headers;
    $self->{oldFields} = $self->get_exiftool_fields($infile);

    get_logger()->trace("Remediating $infile to $outfile");

    foreach my $field (qw(ImageWidth ImageHeight Compression)) {
        $self->copy_old_to_new( "Jpeg2000:$field", "XMP-tiff:$field" );
    }
    foreach my $field (qw(Make Model)) {
        $self->copy_old_to_new( "IFD0:$field", "XMP-tiff:$field" );
    }

    # handle old version of exiftool
    if ( not defined $self->{oldFields}->{'Jpeg2000:ColorSpace'} ) {
        $self->{oldFields}->{'Jpeg2000:ColorSpace'} =
          $self->{oldFields}->{'Jpeg2000:Colorspace'};
    }

    # For IA, ColorSpace should always be sRGB. Only set these fields if they
    # aren't already defined.
    if ( defined $self->{oldFields}->{'Jpeg2000:ColorSpace'} and $self->{oldFields}->{'Jpeg2000:ColorSpace'} eq 'sRGB' ) {
        $self->{newFields}{'XMP-tiff:BitsPerSample'} = '8, 8, 8';
        $self->{newFields}{'XMP-tiff:PhotometricInterpretation'} = 'RGB'; 
        $self->{newFields}{'XMP-tiff:SamplesPerPixel'} = '3';
    }

    # Other package types may have grayscale JP2s that need remediation.
    # Final image validation should kick these out if grayscale is not
    # expected.
    if ( defined $self->{oldFields}->{'Jpeg2000:ColorSpace'} and $self->{oldFields}->{'Jpeg2000:ColorSpace'} eq 'Grayscale' ) {
        $self->{newFields}{'XMP-tiff:BitsPerSample'} = '8';
        $self->{newFields}{'XMP-tiff:PhotometricInterpretation'} = 'BlackIsZero';
        $self->{newFields}{'XMP-tiff:SamplesPerPixel'} = '1';
    }

    # Orientation should always be normal
    $self->set_new_if_undefined( 'XMP-tiff:Orientation',
        'Horizontal (normal)' );


    # normalize the date to ISO8601 if it is close to that; assume UTC if no time zone given (rare in XMP)
    my $normalized_date = fix_iso8601_date($self->{'oldFields'}{'XMP-tiff:DateTime'});
    $normalized_date = $set_if_undefined_headers->{'XMP-tiff:DateTime'} if not defined $normalized_date;
    $self->{newFields}{'XMP-tiff:DateTime'}  = $normalized_date;

    my $resolution = undef;

    # try to get resolution from JPEG2000 headers
    if ( !$force_headers->{'Resolution'} ) {

      foreach my $prefix (qw(Jpeg2000:Capture Jpeg2000:Display IFD0:)) {
        my $xres = $self->{oldFields}->{$prefix . 'XResolution'};
        my $yres = $self->{oldFields}->{$prefix . 'YResolution'};

        next if not defined $xres and not defined $yres;

        get_logger()->warn("Non-square pixels??! XRes $xres YRes $yres")
          if ( ( $xres or $yres ) and $xres != $yres );

        if ($xres) {
          my $xresunit;
          my $yresunit;
          if($prefix =~ /^Jpeg2000/) {
            $xresunit =
              $self->{oldFields}->{$prefix . 'XResolutionUnit'};
            $yresunit =
              $self->{oldFields}->{$prefix . 'YResolutionUnit'};
          } else {
            $xresunit = $self->{oldFields}->{$prefix . 'ResolutionUnit'};
            $yresunit = $xresunit;
          } 

          get_logger()->warn("Resolution unit awry")
            if ( not $xresunit or not $yresunit or $xresunit ne $yresunit );

          my $dpi_resolution = $self->_dpi($xres,$xresunit);

          if(defined $dpi_resolution and $dpi_resolution >= 100) {
            # Absurdly low DPI is likely to be an error or default, so don't
            # use it and try to get it from somewhere else if it is < 100
            $force_headers->{Resolution} = $resolution;
          }
        }
      }


    }

    $self->_set_new_resolution($force_headers,$set_if_undefined_headers);

    # Add other provided new headers if requested and the file does not
    # already have a value set for the given field
    while ( my ( $field, $val ) = each(%$set_if_undefined_headers) ) {
        $self->set_new_if_undefined( $field, $val );
    }

    # first copy old values, since kdu_munge will eat the XMP if it is
    # present
    my $exifTool = new Image::ExifTool;
    $exifTool->Options('ScanForXMP' => 1);
    $exifTool->Options('IgnoreMinorErrors' => 1);
    my $info = $exifTool->SetNewValuesFromFile( $infile, '*:*' );
    while ( my ( $key, $val ) = each(%$info) ) {
        if ( $key eq 'Error' ) {
            croak("Error extracting old headers: $!");
        }
    }

    # then copy new fields
    while ( my ( $field, $val ) = each( %{ $self->{newFields} } ) ) {
        $exifTool->SetNewValue($field); # first reset existing value, if any
        my ( $success, $errStr ) = $exifTool->SetNewValue( $field, $val );
        if ( defined $errStr ) {
            croak("Error setting new tag $field => $val: $errStr\n");
        }
    }

    my $kdu_munge = get_config('kdu_munge');
    if (    $self->{volume}->get_nspkg()->get('use_kdu_munge')
        and defined $kdu_munge
        and $kdu_munge )
    {
        system("$kdu_munge -i '$infile' -o '$outfile' > /dev/null 2>&1")
          and $self->set_error(
            "OperationFailed",
            file      => $outfile,
            operation => "kdu_munge"
          );

        $self->update_tags( $exifTool, $outfile );
    }
    else {
        $self->update_tags( $exifTool, $outfile, $infile );
    }

}

sub _dpi {
  my $self = shift;
  my $xres = shift;
  my $xresunit = shift;
  my $factor = undef;

  return unless $xres and $xresunit;

  $xresunit eq 'um' and $factor = 25400;
  $xresunit eq '0.01 mm' and $factor = 2540;
  $xresunit eq '0.1 mm' and $factor = 254;
  $xresunit eq 'mm' and $factor = 25.4;
  $xresunit eq 'cm' and $factor = 2.54;
  $xresunit eq 'm' and $factor = 0.0254;
  $xresunit eq 'km' and $factor = 0.0000254;
  $xresunit eq 'in' and $factor = 1;
  $xresunit eq 'inches' and $factor = 1;

  if(defined $factor) {
    return sprintf("%.0f",$xres * $factor);
  } else {
    return;
  }
}

sub _set_new_resolution {
  my $self = shift;
  my $force_headers = shift;
  my $set_if_undefined_headers = shift;

  my $xmp_resolution = $self->_dpi($self->{oldFields}->{'XMP-tiff:XResolution'},$self->{oldFields}->{'XMP-tiff:ResolutionUnit'});

  # if the resolution in the XMP is nonsense, ensure it gets updated with any
  # info we might have even if we aren't otherwise forcing the resolution
  my $force_res = (defined $force_headers->{'Resolution'} or (defined $xmp_resolution and $xmp_resolution < 100));

  my $resolution = $force_headers->{'Resolution'};
  $resolution ||= $set_if_undefined_headers->{'Resolution'};

  return unless defined $resolution;

  if ($force_res) {
      $self->{newFields}->{'XMP-tiff:XResolution'}    = $resolution;
      $self->{newFields}->{'XMP-tiff:YResolution'}    = $resolution;
      $self->{newFields}->{'XMP-tiff:ResolutionUnit'} = 'inches';
  }
  else {
      $self->set_new_if_undefined( 'XMP-tiff:XResolution', $resolution );
      $self->set_new_if_undefined( 'XMP-tiff:YResolution', $resolution );
      $self->set_new_if_undefined( 'XMP-tiff:ResolutionUnit', 'inches' );
  }

  if (defined $self->{oldFields}->{'IFD0:XResolution'})
  {
    # Overwrite IFD0:XResolution/IFD0:YResolution if they are present
    $self->{newFields}->{'IFD0:XResolution'} = $resolution;
    $self->{newFields}->{'IFD0:YResolution'} = $resolution;
    $self->{newFields}->{'IFD0:ResolutionUnit'} = 'inches';
  }
} sub prevalidate_field {
    my $self      = shift;
    my $fieldname = shift;
    my $expected  = shift
      ; # can be a scalar or an array ref, if there are multiple permissible values
    my $remediable = shift;
    my $ok         = 0;

    my $actual = $self->{oldFields}{$fieldname};
    my $error_class = $remediable ? 'PREVALIDATE_REMEDIATE' : 'PREVALIDATE_ERR';

    if ( not defined $actual ) {
        $ok = 0;
    }
    elsif ( not defined $expected ) {

        # any value is OK
        $ok = 1;
    }
    elsif (
        ( !ref($expected) and $actual eq $expected )

        # OK value
        or
        ( ref($expected) eq 'ARRAY' and ( grep { $_ eq $actual } @$expected ) )
      )
    {
        $ok = 1;
    }
    else {

        # otherwise: unexpected/invalid value
        $ok = 0;
    }

    return $ok;

}

=item expand_lossless_jpeg2000()

$self->expand_lossless_jpeg2000($volume, $path, $files)

Runs JHOVE to find any losslessly compressed JPEG2000 images and expands them 
to TIFF. The TIFF remediation will then recompress the TIFF to a JPEG2000 image
that meets spec.

$files is a reference to an array of filenames
$path is the base directory containing all the files in $files

If the JPEG2000 image is named FILENAME.jp2, it will be decompressed to
FILENAME.tif, and FILENAME.jp2 will be removed.

=cut

sub expand_lossless_jpeg2000 {
    my ($self, $volume, $path, $files) = @_;

    my $transformation_xp = XML::LibXML::XPathExpression->new(
                    "/jhove:jhove/jhove:repInfo/" .
                    "jhove:properties/jhove:property[jhove:name='JPEG2000Metadata']/jhove:values/" .
                    "jhove:property[jhove:name='Codestreams']/jhove:values/jhove:property[jhove:name='Codestream']/jhove:values/" .
                    "jhove:property[jhove:name='CodingStyleDefault']/jhove:values/" . 
                    "jhove:property[jhove:name='Transformation']/jhove:values/jhove:value"
                );


    $self->run_jhove(
        $volume,
        $path,
        $files,
        sub {
            my ( $volume, $file, $node ) = @_;
            my $xpc = XML::LibXML::XPathContext->new($node);
            register_namespaces($xpc);

            my $transformation = $xpc->findvalue($transformation_xp);
            if (not defined $transformation) {
                # malformed JPEG2000 image
                $self->set_error("BadFile",file => $file, detail => "Can't find Transformation in JHOVE output");
            } elsif ($transformation eq '1') {
                # lossless compression
                my $outfile = $file;
                $outfile =~ s/\.jp2$/.tif/;

                system("/l/local/bin/kdu_expand -i '$path/$file' -o '$path/$outfile' > /dev/null 2>&1");

                unlink("$path/$file");
            }

        },
        "-m JPEG2000-hul"
    );
}

=item remediate_tiffs()

$self->remediate_tiffs($volume,$path,$tiffs,$headers_sub);

Runs jhove and calls image_remediate for all tiffs in $tiffs. 
$tiffs is a reference to an array of filenames.
$path is the base directory containing all the files in $tiffs.

$headers_sub is a callback taking the filename as a parameter and returning the
force_headers, set_if_undefined_headers and optionally the out_file parameters
for remediate_image (qv)

=cut

sub remediate_tiffs {

    my ( $self, $volume, $tiffpath, $files, $headers_sub ) = @_;

    my $repStatus_xp = XML::LibXML::XPathExpression->new(
        '/jhove:jhove/jhove:repInfo/jhove:status');
    my $error_xp = XML::LibXML::XPathExpression->new(
'/jhove:jhove/jhove:repInfo/jhove:messages/jhove:message[@severity="error"]'
    );
    my $stage_path = $volume->get_staging_directory();
    my $objid      = $volume->get_objid();

# check if Artist and/or ModifyDate header is full of binary junk; if so remove it
    foreach my $tiff (@$files) {
        my $headers   = $self->get_exiftool_fields("$tiffpath/$tiff");
        my $needwrite = 0;
        my $exiftool  = new Image::ExifTool;
        $exiftool->Options('ScanForXMP' => 1);
        $exiftool->Options('IgnoreMinorErrors' => 1);
        foreach my $field ( 'IFD0:ModifyDate', 'IFD0:Artist' ) {
            my $header = $headers->{$field};
            eval {

                # see if the header is valid ascii or UTF-8
                my $decoded_header =
                  decode( 'utf-8', $header, Encode::FB_CROAK );
            };
            if ($@) {

                # if not, strip it
                $exiftool->SetNewValue($field);
                $needwrite = 1;
            }

        }
        if ($needwrite) {
            $exiftool->WriteInfo("$tiffpath/$tiff");
        }

    }

    $self->run_jhove(
        $volume,
        $tiffpath,
        $files,
        sub {
            my ( $volume, $file, $node ) = @_;
            my $xpc = XML::LibXML::XPathContext->new($node);
            my ( $force_headers, $set_if_undefined_headers, $renamed_file ) =
              ( undef, undef, undef );
            register_namespaces($xpc);

            $self->{jhoveStatus} = $xpc->findvalue($repStatus_xp);
            $self->{jhoveErrors} =
              [ map { $_->textContent } $xpc->findnodes($error_xp) ];

            # get headers that may depend on the individual file
            if ($headers_sub) {
                ( $force_headers, $set_if_undefined_headers, $renamed_file ) =
                  &$headers_sub($file);
            }

            my $outfile = "$stage_path/$file";
            $outfile = "$stage_path/$renamed_file" if ( defined $renamed_file );

            $self->remediate_image( "$tiffpath/$file", $outfile, $force_headers,
                $set_if_undefined_headers );
        },
        "-m TIFF-hul"
    );
}

sub convert_tiff_to_jpeg2000 {
    my $self        = shift;
    my $volume      = $self->{volume};
    my $seq         = shift;

    my $preingest_dir = $volume->get_preingest_directory();
    my $infile  = "$preingest_dir/$seq.tif";
    my $outfile = "$preingest_dir/$seq.jp2";
    my ( $field, $val );

    # From Roger:
    #
    # $levels would be derived from the largest dimension; minimum is 5.
    #
    # - 0     < x <= 6400  : nlev=5
    # - 6400  < x <= 12800 : nlev=6
    # - 12800 < x <= 25600 : nlev=7
    my $maxdim = max(
        $self->{oldFields}->{'IFD0:ImageWidth'},
        $self->{oldFields}->{'IFD0:ImageHeight'}
    );
    my $levels = max( 5, ceil( log( $maxdim / 100 ) / log(2) ) - 1 );

    # try to compress the TIFF -> JPEG2000
    get_logger()->trace("Compressing $infile to $outfile");
    my $kdu_compress = get_config('kdu_compress');

    if(not defined $self->{recorded_image_compression}) {
        $volume->record_premis_event('image_compression');
        $self->{recorded_image_compression} = 1;
    }

    # Settings for kdu_compress recommended from Roger Espinosa. "-slope"
    # is a VBR compression mode; the value of 42988 corresponds to pre-6.4
    # slope of 51180, the current (as of 5/6/2011) recommended setting for
    # Google digifeeds.
    #
    # 43300 corresponds to the old recommendation of 51492 for general material.

    # save some info from the TIFF
    foreach my $tag (qw(Artist Make Model)) {
      my $tagvalue = $self->{oldFields}->{"IFD0:$tag"};
      $tagvalue = $self->{oldFields}->{"XMP-tiff:$tag"} if not defined $tagvalue;
      $self->{newFields}->{"XMP-tiff:$tag"} = $tagvalue if defined $tagvalue;
    }

    # strip off the XMP to prevent confusion during conversion
    my $exifTool = new Image::ExifTool;
    $exifTool->Options('ScanForXMP' => 1);
    $exifTool->Options('IgnoreMinorErrors' => 1);
    $exifTool->SetNewValue('XMP',undef,Protected => 1);
    $self->update_tags( $exifTool, $infile );

    # first decompress & strip ICC profiles
    my $imagemagick = get_config('imagemagick');
    my $imagemagick_cmd = qq($imagemagick);
    # make sure it's 24-bit RGB or 8-bit grayscale and keep it that way
    if($self->{oldFields}->{'IFD0:SamplesPerPixel'} eq '3'
        and ($self->{oldFields}->{'IFD0:BitsPerSample'} eq '8'
            or $self->{oldFields}->{'IFD0:BitsPerSample'} eq '8 8 8')) {
        $imagemagick_cmd .= qq( -type TrueColor)
    } elsif($self->{oldFields}->{'IFD0:BitsPerSample'} eq '8' 
            and $self->{oldFields}->{'IFD0:SamplesPerPixel'} eq '1') {
        $imagemagick_cmd .= qq( -type Grayscale -depth 8)
    }

    # strip 

    system( "$imagemagick_cmd -compress None $infile -strip $infile.unc.tif > /dev/null 2>&1" )
            and $self->set_error("OperationFailed", operation => "imagemagick", file => $infile, detail => "decompress and ICC profile strip failed: returned $?");

    system(
"$kdu_compress -quiet -i '$infile.unc.tif' -o '$outfile' Clevels=$levels Clayers=8 Corder=RLCP Cuse_sop=yes Cuse_eph=yes 'Cmodes=RESET|RESTART|CAUSAL|ERTERM|SEGMARK' -no_weights -slope 42988 > /dev/null 2>&1"
      )

      and $self->set_error(
        "OperationFailed",
        operation => "kdu_compress",
        file      => $infile,
        detail    => "kdu_compress returned $?"
      );

    # then set new metadata fields - the rest will automatically be 
    # set from the JP2
    foreach $field ( qw( XResolution YResolution ResolutionUnit Artist Make Model))
    {
        $self->copy_old_to_new( "IFD0:$field", "XMP-tiff:$field" );
    }

    # Don't worry about setting all fields here, since it will also be run through
    # the JPEG2000 remediation.
    $self->copy_old_to_new( "IFD0:ModifyDate", "XMP-tiff:DateTime" );
    $self->set_new_if_undefined( "XMP-tiff:Compression", "JPEG 2000" );
    $self->set_new_if_undefined( "XMP-tiff:Orientation", "normal" );

    $exifTool = new Image::ExifTool;
    $exifTool->Options('ScanForXMP' => 1);
    $exifTool->Options('IgnoreMinorErrors' => 1);
    while ( ( $field, $val ) = each( %{ $self->{newFields} } ) ) {
        my ( $success, $errStr ) = $exifTool->SetNewValue( $field, $val );
        if ( defined $errStr ) {
            croak("Error setting new tag $field => $val: $errStr\n");
        }
    }

    $self->update_tags( $exifTool, "$outfile" );
}

# normalize the date to ISO8601 if it is close to that; assume UTC if no time zone given (rare in XMP)
sub fix_iso8601_date {
  my $datetime = shift;

  if (defined $datetime and $datetime =~ /^(\d{4})[:\/-](\d\d)[:\/-](\d\d)[T ](\d\d):(\d\d)(:\d\d)?(Z|[+-]\d{2}:\d{2})?$/ ) {
    my ($Y,$M,$D,$h,$m,$s,$tz) = ($1,$2,$3,$4,$5,$6,$7);
    $s = ':00' if not defined $s;
    $tz = 'Z' if not defined $tz;
    return "$Y-$M-${D}T$h:$m$s$tz";
  } else {
    # missing or very badly formatted date
    return;
  }
}

# normalize to TIFF 6.0 spec "YYYY:MM:DD HH:MM:SS"
sub fix_tiff_date {
  my $datetime = shift;

  return if not defined $datetime;

  if ( $datetime =~ /^(\d{4}).(\d{2}).(\d{2}).(\d{2}).(\d{2}).(\d{2})/ )
  {
    return  "$1:$2:$3 $4:$5:$6";
  }
  elsif ( $datetime =~ /^(\d{4}).?(\d{2}).?(\d{2})/ )
  {
    return "$1:$2:$3 00:00:00";
  }
  # two digit year from 1990s; assume mm/dd/yy
  elsif ( $datetime =~ /^(\d{2})\/(\d{2})\/(9\d)$/ ) {
    return  "19$3:$1:$2 00:00:00";
  } 
  # four digit year, no time; assume mm/dd/yy
  elsif ( $datetime =~ qr(^(\d{2})[/:-](\d{2})[/:-](\d{4})$)) {
    return "$3:$1:$2 00:00:00";
  }
  else 
  {
    # garbage / unparseable
    return; 
  }

}

# update with remediated dates without regard to whether they are null or not
sub set_new_date_fields {
  my $self = shift;
  my $new_tiffdate = shift;
  my $new_xmpdate = shift;

  $self->{newFields}{'IFD0:ModifyDate'} = $new_tiffdate;
  if($self->needs_xmp) {
    $self->{newFields}{'XMP-tiff:DateTime'} = $new_xmpdate;
  }
}

sub fix_datetime {
  my $self = shift;

  my $default_datetime = shift;

  my $tiff_datetime = fix_tiff_date($self->{oldFields}{'IFD0:ModifyDate'});
  my $xmp_datetime = fix_iso8601_date($self->{oldFields}{'XMP-tiff:DateTime'});

  $self->set_new_date_fields($tiff_datetime,$xmp_datetime);
  $self->fix_datetime_missing($tiff_datetime,$xmp_datetime,$default_datetime);

  # fix_datetime_missing may have updated these
  $self->fix_datetime_mismatch($self->{newFields}{'IFD0:ModifyDate'},
                               $self->{newFields}{'XMP-tiff:DateTime'},
                               $default_datetime);

}

sub fix_datetime_missing {
  my $self = shift;
  my $tiff_datetime = shift;
  my $xmp_datetime = shift;
  my $default_datetime = shift;

  # copy TIFF DateTime if we have it and need the XMP
  if(defined $tiff_datetime and $self->needs_xmp and not defined $xmp_datetime) {
    $self->set_new_date_fields($tiff_datetime,$tiff_datetime);
  }

  # copy XMP DateTime if we have it and need the TIFF DateTime
  elsif(defined $xmp_datetime and not defined $tiff_datetime) {
    $self->set_new_date_fields($xmp_datetime,$xmp_datetime);
  }

  # if we have neither, set both (set_new_date_fields will only set the
  # XMP if needed)
  elsif(not defined $xmp_datetime and not defined $tiff_datetime) {
    $self->set_new_date_fields($default_datetime,$default_datetime);
  }
}

sub fix_datetime_mismatch {
  my $self = shift;
  my $tiff_datetime = shift;
  my $xmp_datetime = shift;
  my $default_datetime = shift;

  # if there is no XMP, we don't need to make sure they match
  return unless $self->needs_xmp;

  if ($self->tiff_xmp_date_mismatch($tiff_datetime,$xmp_datetime))  {
    $self->set_new_date_fields($default_datetime,$default_datetime);
  }
}

sub tiff_xmp_date_mismatch {
  my $self = shift;
  my $tiff_datetime = shift;
  my $xmp_datetime = shift;
  my $mix_datetime = undef;

  if(defined $tiff_datetime and
    # accept tiff-style or ISO8601 style
    $tiff_datetime =~ /^(\d{4}).(\d{2}).(\d{2}).(\d{2}).(\d{2}).(\d{2})([+-]\d{2}:\d{2})?$/) {
    $mix_datetime = "\1-\2-\3T\4:\5:\6";
  } else {
    # shouldn't happen at this point - tiff_datetime should either be null or
    # well formatted
    $self->set_error("BadValue",field => 'IFD0:ModifyDate',actual =>
      $tiff_datetime,detail=>'Expected format YYYY:MM:DD HH:mm:ss');
    return undef;
  }

  return (defined $xmp_datetime and defined $mix_datetime 
      and $xmp_datetime !~ /^\Q$mix_datetime\E([+-]\d{2}:\d{2})?/)
}

sub needs_xmp {
  my $self = shift;
  return (grep { $_ =~ /^XMP-/ } keys(%{$self->{oldFields}}) )
}

1;

__END__

=head1 NAME

HTFeed::Stage::ImageRemediate - Image file processing

=head1 DESCRIPTION

ImageRemediate.pm is the main class for image file remediation.
The class provides methods for cleaning up image files prior to ingest.

=head2 METHODS

=over 4

=item get_exiftool_fields()

Returns a hash of all the tags found by ExifTool in the specified file.
The keys are in the format GroupName:TagName in the same format as the
tag names returned by exiftool -X $file

$fields_ref = get_exiftool_fields($file)

=item remediate_image()

Prevalidates and remediates the image headers in $oldfile and writes the results as $newfile.

usage: $self->remediate_image($oldfile,$newfile,$force_headers,$set_if_undefined_headers)

$force_headers and $set_if_undefined_headers are references to hashes:
{ header => $value, 
header2 => $value, ...}

Additional parameters can be passed to set the value for particular fields.
$force_headers lists headers to force whether or not they are present, and
$set_if_undefined_heaeders gives headers to set if they are not already
defined.

For example,

$stage->remediate_image($oldfile,$newfile,{'XMP-dc:source' => 'Internet Archive'},{'XMP-tiff:Make' => 'Canon'})

will force the XMP-dc:source field to 'Internet Archive' whether or not it is already present,
and set XMP-tiff:Make to Canon if XMP-tiff:Make is not otherwise defined.

The special header 'Resolution' can be set to set X/Y resolution related fields; it should be 
specified in pixels per inch.

=item update_tags()

Updates the tags in outfile with the parameters set in the given exiftool

$self->update_tags($exifTool,$outfile);

=item copy+old_to_new()

Copies old field value to the new field value, but only if the old value is defined
and the new one isn't.

$self->copy_old_to_new($oldFieldName, $newFieldName);

=item set_new_if_undefined()

Copies old field value to the new field value, but only if the old value is defined
and the new one isn't.

$self->set_new_if_undefined($newFieldName,$newFieldVal);

=item remediate_tiffs()

$self->remediate_tiffs($volume,$path,$tiffs,$headers_sub);

Runs jhove and calls image_remediate for all tiffs in $tiffs. 
$tiffs is a reference to an array of filenames.
$path is the base directory containing all the files in $tiffs.

$headers_sub is a callback taking the filename as a parameter
and returning the force_headers and set_if_undefined_headers parameters for
remediate_image (qv)

=back

=head1 AUTHOR

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
