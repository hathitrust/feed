package HTFeed::PackageType::DLXS::BibTargetRemove;

use warnings;
use strict;
use base qw(HTFeed::Stage);
use Image::ExifTool;
use File::Basename;
use HTFeed::Config qw(get_config);

# Remove bibliographic record targets based on OCR

use Log::Log4perl qw(get_logger);

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $ingest_dir = $volume->get_staging_directory();
    my $objid = $volume->get_objid();

    my @removed = ();
    
    foreach my $txt ( @{$volume->get_file_groups()->{ocr}->get_filenames()} ) {
        my $txt_fh;
        open($txt_fh,"<","$ingest_dir/$txt") or die("Can't open $txt: $!");
        local $/;
        my $txt_content = <$txt_fh>;
        close($txt_fh);
        get_logger()->trace("Checking $txt for bib target");


        if($txt_content =~ /BIBLIOGRAPHIC RECORD TARGET/i) {
            get_logger()->debug("Removing bibliographic target $txt");
            my @toremove = glob($ingest_dir . "/" . basename($txt,'.txt') . ".*");
            $self->set_error("MissingFile",file => basename($txt,'.txt') . ".*") if scalar(@toremove) < 2;
            push(@removed,@toremove);
        }

    }

    foreach my $toremove (@removed) {
        unlink($toremove) or die("Can't unlink $toremove: $!");
    }
    if(@removed and !$self->{failed}) {
        @removed = map {basename($_)} @removed;
        my $outcome = new PREMIS::Outcome('success');
        $outcome->add_file_list_detail( "bibliographic target removed",
                        "removed", \@removed);
        $volume->record_premis_event('target_remove',outcome => $outcome);
        
    }

    $self->_set_done();
    return $self->succeeded();

}

sub stage_info{
    return {success_state => 'target_removed', failure_state => ''};
}

1;

__END__
