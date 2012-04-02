package HTFeed::PackageType::DLXS::ImageRemediate;

use warnings;
use strict;
use base qw(HTFeed::Stage::ImageRemediate);

use Log::Log4perl qw(get_logger);
use File::Basename;

# how much can guessed x & y resolution differ in jp2?
# Allow them to differ by 10% before complaining.
my $NONSQUARE_TOLERANCE = 0.1;

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $preingest_path = $volume->get_preingest_directory();
    my $stage_path = $volume->get_staging_directory();
    

    # remediate TIFFs
    my @tiffs = map { basename($_) } glob("$preingest_path/[0-9]*.tif");
    $self->remediate_tiffs($volume,$preingest_path,\@tiffs,

        # return extra fields to set that depend on the file
        sub {
            my $file = shift;
            # three fields to remediate: docname, datetime, artist.
            # docname: remediate only if missing; set to $barcode/$filename.
            # datetime: remediate from docname if possible. otherwise use loadcd.log
            # artist: remediate from docname if possible, otherwise use loadcd.log
            my $force_fields = {'IFD0:DocumentName' => join('/',$volume->get_objid(),$file) };
            my $set_if_undefined = {};
            if(my ($datetime,$artist) = $self->get_tiff_info("$preingest_path/$file",'tiff')) {
                $set_if_undefined->{'IFD0:ModifyDate'} = $datetime;
                $set_if_undefined->{'IFD0:Artist'} = $artist;
            }

            return ( $force_fields, $set_if_undefined);
        }
    );

    # remediate JP2s

    foreach my $jp2_submitted (glob("$preingest_path/*.jp2"))
    {
        my $jp2_remediated = basename($jp2_submitted);
        my $jp2_fields = $self->get_exiftool_fields($jp2_submitted);
        # change to form 0000010.jp2 instead of p0000010.jp2
        $jp2_remediated =~ s/^p/0/;
        # tiff version of this jp2 for extracting certain fields
        my $tiff = "$preingest_path/" . basename($jp2_remediated,'.jp2') . ".tif";
        my $force_fields = {'XMP-dc:source' => join('/',$volume->get_objid(),$jp2_remediated) };
        $jp2_remediated = "$stage_path/$jp2_remediated";

        my $set_if_undefined = {};
        # old DocumentName may contain some valuable information!

        my ($datetime, $artist, $tiff_fields) = $self->get_tiff_info($tiff,'jp2');
        $set_if_undefined->{'XMP-tiff:DateTime'} = $datetime if defined $datetime;
        $set_if_undefined->{'XMP-tiff:Artist'} = $artist if defined $artist;

        # attempt to determine the physical size of the page from the tiff file,
        # then use that to determine the resolution of the jp2
        if(defined $tiff_fields->{'IFD0:ImageHeight'}
                and defined $tiff_fields->{'IFD0:ImageWidth'}
                and defined $tiff_fields->{'IFD0:XResolution'}
                and defined $tiff_fields->{'IFD0:YResolution'} ) {
            my $jpeg2000_fields = $self->get_exiftool_fields($jp2_submitted);
            my $xsize_inches = $tiff_fields->{'IFD0:ImageWidth'}/$tiff_fields->{'IFD0:XResolution'};
            my $ysize_inches = $tiff_fields->{'IFD0:ImageHeight'}/$tiff_fields->{'IFD0:YResolution'};
            my $xres  = $jpeg2000_fields->{'Jpeg2000:ImageWidth'} / $xsize_inches;
            my $yres = $jpeg2000_fields->{'Jpeg2000:ImageHeight'} / $ysize_inches;
            if( ($xres - $yres)/$xres < $NONSQUARE_TOLERANCE) {
                $set_if_undefined->{Resolution} = sprintf("%.0f/1",$xres);
            } else {
                get_logger()->trace("Gross TIFF/JP2 mismatch on $jp2_submitted? xres=$xres, yres=$yres");
            }
        }

        $self->remediate_image( $jp2_submitted, $jp2_remediated, $force_fields, $set_if_undefined );
    }




    $volume->record_premis_event('image_header_modification');
    
    $self->_set_done();
    return $self->succeeded();
}

# extract DateTime and Artist from TIFF
sub get_tiff_info {
    my $self = shift;
    my $volume = $self->{volume};
    my $tiff = shift;
    my $fmt = shift;

    my ($load_date, $artist, $tiff_fields);

    if(-e $tiff) {
        $tiff_fields = $self->get_exiftool_fields($tiff);
        $artist = $tiff_fields->{'IFD0:Artist'};
        $load_date = $tiff_fields->{'IFD0:ModifyDate'};
        if(defined $docname and $docname =~ qr#^(\d{2})/(\d{2})/(\d{4}),(\d{2}):(\d{2}):(\d{2}),"(.*)"#) {
            if($fmt eq 'tiff') {
                $load_date = "$3:$1:$2 $4:$5:$6" if not defined $load_date;
            } else {
                $load_date = "$3-$1-$2T$4$5$6" if not defined $load_date;
            }
            $artist = $7 if not defined $artist;
        }
    }

    my $loadcd_info = $volume->get_loadcd_info();
    $artist = $loadcd_info->{artist} if not defined $artist and defined $loadcd_info->{artist};

    if(defined $loadcd_info->{load_date}) {
        $load_date = $loadcd_info->{load_date};
        # fix separator
        if($fmt eq 'tiff') {
            $load_date =~ s/-/:/g;
        } else {
            $load_date =~ s/ /T/;
        }
    }
    # set default artist
    $artist = "University of Michigan" if not defined $artist;
    return ($load_date,$artist,$tiff_fields);
}

1;

__END__
