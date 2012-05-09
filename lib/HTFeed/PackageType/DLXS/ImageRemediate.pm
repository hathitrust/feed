package HTFeed::PackageType::DLXS::ImageRemediate;

use warnings;
use strict;
use base qw(HTFeed::Stage::ImageRemediate);

use Log::Log4perl qw(get_logger);
use File::Basename;
use Date::Manip;
use POSIX qw(strftime);

# minimum dimensions for JP2 are set to trade paperback digitized at 400 DPI
my $MIN_XSIZE = 2128;
my $MIN_YSIZE = 3404;

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

        # get file timestamp??!
        $set_if_undefined->{'XMP-tiff:DateTime'} = strftime( "%Y:%m:%d %H:%M:%S%z", 
            localtime((stat($jp2_submitted))[9]));
        $set_if_undefined->{'XMP-tiff:Artist'} = 'University of Michigan';

        # Assume we scanned at 400 DPI; does that lead to a ridiculous physical size?
        # If not set resolution to 400 if it is not already present
        my $xsize  = $jp2_fields->{'Jpeg2000:ImageWidth'};
        my $ysize = $jp2_fields->{'Jpeg2000:ImageHeight'};
        if($xsize >= $MIN_XSIZE and $ysize >= $MIN_YSIZE) {
            $set_if_undefined->{'Resolution'} = '400/1';
        } else {
            $self->set_error("BadFile",
                file => $jp2_submitted,
                field => "Composite:ImageSize",
                actual => $jp2_fields->{'Composite:ImageSize'},
                expected => ">${MIN_XSIZE}x${MIN_YSIZE}"
            );
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
        my $docname = $tiff_fields->{'IFD0:DocumentName'};
        if(defined $docname and $docname =~ qr#^(\d{2})/(\d{2})/(\d{4}),(\d{2}):(\d{2}):(\d{2}),"(.*)"#) {
            $load_date = "$3:$1:$2 $4:$5:$6" if not defined $load_date;
            $artist = $7 if not defined $artist;
        }
    }

    my $loadcd_info = $volume->get_loadcd_info();
    $artist = $loadcd_info->{artist} if not defined $artist and defined $loadcd_info->{artist};

    if(defined $loadcd_info->{load_date}) {
        $load_date = $loadcd_info->{load_date};
        # fix separator
        $load_date =~ s/-/:/g;
    }

    # set default artist and load date: file timestamp / University of Michigan
        
    $load_date = strftime("%Y:%m:%d %H:%M:%S", localtime((stat($tiff))[9])) if not defined $load_date;
    $artist = "University of Michigan" if not defined $artist;
    return ($load_date,$artist,$tiff_fields);
}

1;

__END__
