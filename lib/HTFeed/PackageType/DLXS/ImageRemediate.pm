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
    $self->remediate_tiffs($volume,$preingest_path,\@tiffs);

    # remediate JP2s

    foreach my $jp2_submitted (glob("$preingest_path/*.jp2"))
    {
        my $jp2_remediated = basename($jp2_submitted);
        # change to form 0000010.jp2 instead of p0000010.jp2
        $jp2_remediated =~ s/^p/0/;
        $jp2_remediated = "$stage_path/$jp2_remediated.jp2";

        $self->remediate_image( $jp2_submitted, $jp2_remediated );
    }

    $volume->record_premis_event('image_header_modification');
    
    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
