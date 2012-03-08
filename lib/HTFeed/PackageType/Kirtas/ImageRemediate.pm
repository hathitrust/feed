package HTFeed::PackageType::Kirtas::ImageRemediate;

use warnings;
use strict;
use base qw(HTFeed::Stage::ImageRemediate);

use Log::Log4perl qw(get_logger);
use File::Basename qw(dirname);

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $mets_xc = $volume->get_kirtas_mets_xpc();
    my $stage_path = $volume->get_staging_directory();
    my $objid = $volume->get_objid();

    print STDERR "Prevalidating and remediating images..";

    my $capture_time = $volume->get_capture_time();

    my @tiffs = ();
    my $tiffpath = undef;
    foreach my $image_node (
        $mets_xc->findnodes(
            '//mets:fileGrp[@ID="BSEGRP"]/mets:file/mets:FLocat/@xlink:href')
    )
    {


        my $img_dospath = $image_node->nodeValue();
        $img_dospath =~ s/JPG$/JP2/;
        my $img_submitted_path = $volume->dospath_to_path($img_dospath);

        $img_dospath =~ /($objid)_(\d+)\.(JP2|TIF)/i;
        my $img_remediated = lc("$1_$2.$3");
        my $imgtype = lc($3);
        my $img_remediated_path = lc("$stage_path/$img_remediated");

        # To force: source, artist
        # To set if undefined: make, model, datetime
        if($imgtype eq 'jp2') {
            $self->remediate_image( $img_submitted_path, $img_remediated_path,
                {'XMP-dc:source' => "$objid/$img_remediated",
                    'XMP-tiff:Artist' => 'Kirtas Technologies, Inc.',
                    'XMP-tiff:DateTime' => $capture_time}, {} );
        } else {
            if(defined $tiffpath and dirname($img_submitted_path) ne $tiffpath) {
                $self->set_error("UnexpectedError",detail => "two image paths $tiffpath and $img_submitted_path!");
            }
            $tiffpath = dirname($img_submitted_path);
            push(@tiffs,$img_remediated);
        }


    }

    # remediate tiffs
    $self->remediate_tiffs($volume,$tiffpath,\@tiffs,
        { 'IFD0:Artist' => 'Kirtas Technologies, Inc.',
            'IFD0:ModifyDate' => $capture_time}, {} );

    $volume->record_premis_event('image_header_modification');

    $self->_set_done();
    return $self->succeeded();
}


1;

__END__
