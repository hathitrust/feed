package HTFeed::PackageType::UCM::ImageRemediate;

use warnings;
use strict;
use base qw(HTFeed::Stage::ImageRemediate);
use List::Util qw(max min);
use POSIX qw(ceil);
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use Carp;

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $preingest_dir = $volume->get_preingest_directory();
    my $staging_dir = $volume->get_staging_directory();

    # figure out sort order of pages

    my ($anum, $bnum, $asub, $bsub);

    my @sortedpages = sort { 
        if( ($anum) = ($a =~ /\((\d+)\)/)
                and ($bnum) = ($b =~ /\((\d+)\)/)) { 
            return $anum <=> $bnum;
        } elsif ( ($anum,$asub) = ($a =~ /_(\d+)_?(\d+)?/) and
            ($bnum,$bsub) = ($b =~ /_(\d+)_?(\d+)?/) ) {

            if($anum == $bnum) {
                if(not defined $asub) {
                    return -1;
                } elsif(not defined $bsub) {
                    return 1;
                } else {
                    return $asub <=> $bsub;
                }
            } else {
                return $anum <=> $bnum;
            }

        } else {
            die("Can't extract pagenumbers from $a and $b");
        }
    } ( glob("$preingest_dir/*tif") );

    # then convert tif to jp2 & add xmp

    foreach my $i (0..$#sortedpages) {
        # reset remediator;

        $self->{newFields} = {};
        $self->{oldFields} = {};
        my $infile = $sortedpages[$i];
        my $outfile = sprintf("%08d.jp2",$i+1);
        my ($field,$val);
        
        # first read old fields; we need the length to set levels properly
        $self->{oldFields} = $self->get_exiftool_fields($infile);

        # From Roger:
        #
        # $levels would be derived from the largest dimension:
        #
        # - 0     < x <= 800   : nlev=2
        # - 800   < x <= 1600  : nlev=3
        # - 1600  < x <= 3200  : nlev=4
        # - 3200  < x <= 6400  : nlev=5
        # - 6400  < x <= 12800 : nlev=6
        # - 12800 < x <= 25600 : nlev=7
        my $maxdim = max($self->{oldFields}->{'IFD0:ImageWidth'},
            $self->{oldFields}->{'IFD0:ImageHeight'});
        my $levels = max(2,ceil(log($maxdim/100)/log(2)) - 1);
        
        # try to compress the TIFF -> JPEG2000
        get_logger()->info("Compressing $infile to $outfile");
        my $kdu_compress = get_config('kdu_compress');

        # Settings for kdu_compress recommended from Roger Espinosa. "-slope"
        # is a VBR compression mode; the value of 42988 corresponds to pre-6.4
        # slope of 51180, the current (as of 5/6/2011) recommended setting for
        # Google digifeeds.

        system(qq($kdu_compress -quiet -i '$infile' -o '$staging_dir/$outfile' Clevels=$levels Clayers=8 Corder=RLCP Cuse_sop=yes Cuse_eph=yes "Cmodes=RESET|RESTART|CAUSAL|ERTERM|SEGMARK" -no_weights -slope 42988))

          and $self->set_error("OperationFailed",
            operation=>"kdu_compress",
            file=>$infile,
            detail=>"kdu_compress returned $?");

        # then set new metadata fields
        foreach $field  ( qw(ImageWidth ImageHeight BitsPerSample 
                                PhotometricInterpretation Orientation 
                                SamplesPerPixel XResolution YResolution 
                                ResolutionUnit Artist Make Model) ) {
            $self->copy_old_to_new("IFD0:$field","XMP-tiff:$field");
        }

        $self->copy_old_to_new("IFD0:ModifyDate","XMP-tiff:DateTime");
        $self->set_new_if_undefined("XMP-dc:source","$staging_dir/$outfile");
        $self->set_new_if_undefined("XMP-tiff:Compression","JPEG 2000");
        $self->set_new_if_undefined("XMP-tiff:Artist","Universidad Complutense de Madrid");

        my $exifTool = new Image::ExifTool;
        while ( ( $field, $val ) = each(%{$self->{newFields}}) ) {
            my ( $success, $errStr ) = $exifTool->SetNewValue( $field, $val );
            if ( defined $errStr ) {
                croak("Error setting new tag $field => $val: $errStr\n");
            }
        }

        $self->update_tags($exifTool,"$staging_dir/$outfile");
    } 
    $volume->record_premis_event('image_compression');

    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
