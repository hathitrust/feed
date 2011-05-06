package HTFeed::PackageType::Yale::BoilerplateRemove;

use warnings;
use strict;
use base qw(HTFeed::Stage);
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
        if(-e $toblank) {
            get_logger()->debug("Blanking image $bookplate");
            my $imconvert = get_config('imagemagick');
            system("$imconvert $toblank -threshold -1 +matte $toblank") and 
            get_logger()->error("OperationFailed",file=>$toblank,operation=>"blanking",detail=>"ImageMagick returned $?");
        }   else {
            get_logger()->error("MissingFile",file=>$toblank,detail=>"Found in 2restore/bookplate but missing in images");
        }
    }

    $volume->record_premis_event('boilerplate_remove');
    
    $self->_set_done();
    return $self->succeeded();
}

sub stage_info{
    return {success_state => 'boilerplate_removed', failure_state => ''};
}

1;

__END__
