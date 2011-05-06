package HTFeed::PackageType::Yale::BoilerplateRemove;

use warnings;
use strict;
use base qw(HTFeed::Stage);
use Image::ExifTool;
use File::Basename;
use HTFeed::Config qw(get_config);

# Remove Kirtas-added boilerplate. Boilerplate images are listed under
# IMAGES/2Restore/BookPlate.

use Log::Log4perl qw(get_logger);

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $preingest_dir = $volume->get_preingest_directory();
    my $objid = $volume->get_objid();

    my @removed = ();
    
    # Find images under IMAGES/2RESTORE/BOOKPLATE
    # and change them to all-white with imagemagick
    foreach my $bookplate (map { basename($_)} ( glob("$preingest_dir/images/2restore/bookplate/*jp2"))) {
        my $toblank = "$preingest_dir/images/$bookplate";
        if(!-e $toblank) {
            $self->set_error("MissingFile",file=>$toblank,detail=>"Found in 2restore/bookplate but missing in images");
            next;
        }

        get_logger()->debug("Blanking image $bookplate");
        my $imconvert = get_config('imagemagick');
        if( system("$imconvert $toblank -threshold -1 +matte $toblank") )  {
            $self->set_error("OperationFailed",file=>$toblank,operation=>"blanking",detail=>"ImageMagick returned $?");
            next;
        } 

        # force resolution info, since imagemagick strips it :(
        my $exiftool = new Image::ExifTool;
        $exiftool->SetNewValue("XMP-tiff:XResolution",300);
        $exiftool->SetNewValue("XMP-tiff:YResolution",300);
        $exiftool->SetNewValue("XMP-tiff:ResolutionUnit","inches");
        if(!$exiftool->WriteInfo($toblank)) {
            $self->set_error("OperationFailed",file=>$toblank,operation=>"fix resolution info",
                detail=>"ExifTool returned ". $exiftool->GetValue('Error'));
            next;
        } 

        push(@removed,$bookplate);

    }

    if(!$self->{failed}) {
        my $outcome = new PREMIS::Outcome('success');
        $outcome->add_file_list_detail( "boilerplate removed from images",
                        "modified", \@removed);
        $volume->record_premis_event('boilerplate_remove',outcome => $outcome);
        
    }

    $self->_set_done();
    return $self->succeeded();

}

sub stage_info{
    return {success_state => 'boilerplate_removed', failure_state => ''};
}

1;

__END__
