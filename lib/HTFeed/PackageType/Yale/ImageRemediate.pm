package HTFeed::PackageType::Yale::ImageRemediate;

use HTFeed::ImageRemediate;
use warnings;
use strict;
use base qw(HTFeed::Stage);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $mets_xc = $volume->get_yale_mets_xpc();
    my $stage_path = $volume->get_staging_directory();
    my $objid = $volume->get_objid();
    
    print STDERR "Prevalidating and remediating images..";

    my $capture_time = $volume->get_capture_time();

    foreach my $image_node (
        $mets_xc->findnodes(
            '//mets:fileGrp[@ID="BSEGRP"]/mets:file/mets:FLocat/@xlink:href')
      )
    {
        my $jpg_dospath = $image_node->nodeValue();
        $jpg_dospath =~ s/JPG$/JP2/;
        my $jp2_submitted = $volume->dospath_to_path($jpg_dospath);

        $jpg_dospath =~ /($objid)_(\d+)\.JP2/;
        my $jp2_remediated = "$stage_path/$1_$2.jp2";


        HTFeed::ImageRemediate::remediate_image( $jp2_submitted, $jp2_remediated,
            {'XMP-dc:source' => "$objid/$1_$2.jp2",
             'XMP-tiff:Artist' => 'Kirtas Technologies, Inc.',
             'XMP-tiff:DateTime' => $capture_time}, {} );

        # To force: source, artist
        # To set if undefined: make, model, datetime
    }
    $volume->record_premis_event('image_header_modification');
    
    $self->_set_done();
    return $self->succeeded();
}



1;

__END__
