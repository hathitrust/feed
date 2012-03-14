package HTFeed::PackageType::DLXS::ImageRemediate;

use warnings;
use strict;
use base qw(HTFeed::Stage::ImageRemediate);

use Log::Log4perl qw(get_logger);
use File::Basename;

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $preingest_path = $volume->get_preingest_directory();
    my $stage_path = $volume->get_staging_directory();
    

    # remediate TIFFs
    my @tiffs = map { basename($_) } glob("$preingest_path/*.tif");
    $self->remediate_tiffs($volume,$preingest_path,\@tiffs,

        # return extra fields to set that depend on the file
        sub {
            # three fields to remediate: docname, datetime, artist.
            # docname: remediate only if missing; set to $barcode/$filename.
            # datetime: remediate from docname if possible. otherwise use loadcd.log
            # artist: remediate from docname if possible, otherwise use loadcd.log
            my $file = shift;
            my $fields = $self->get_exiftool_fields("$preingest_path/$file");

            my $set_if_undefined = {};
            my $force_fields = {'IFD0:DocumentName' => join('/',$volume->get_objid(),$file) };
            # old DocumentName may contain some valuable information!
            my $docname = $fields->{'IFD0:DocumentName'};

            if($docname =~ qr#^(\d{2})/(\d{2})/(\d{4}),(\d{2}):(\d{2}):(\d{2}),"(.*)"#) {
                $set_if_undefined->{'IFD0:ModifyDate'} = "$3:$1:$2 $4:$5:$6";
                $set_if_undefined->{'IFD0:Artist'} = $7;
            }

            return ( $force_fields, $set_if_undefined);
        }
    );

    # remediate JP2s

    foreach my $jp2_submitted (glob("$preingest_path/*.jp2"))
    {
        my $jp2_remediated = basename($jp2_submitted);
        # change to form 0000010.jp2 instead of p0000010.jp2
        $jp2_remediated =~ s/^p/0/;
        $jp2_remediated = "$stage_path/$jp2_remediated";

        $self->remediate_image( $jp2_submitted, $jp2_remediated );
    }

    $volume->record_premis_event('image_header_modification');
    
    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
