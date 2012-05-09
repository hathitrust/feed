package HTFeed::Stage::Pack;

use warnings;
use strict;
use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use File::Basename qw(basename);
use File::Path qw(remove_tree);
use Log::Log4perl qw(get_logger);

=head1 NAME

HTFeed::Stage::Pack.pm

=head1 DESCRIPTION

 Base class for Pack stage
 Handles compression of ingest package

=cut

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $pt_objid = $volume->get_pt_objid();
    my $stage = $volume->get_staging_directory();

    my @files_to_zip = ();

    # Make a temporary staging directory
    my $zip_stage = get_config('staging'=>'zip');
    my $zipfile_stage = get_config('staging'=>'zipfile');
    mkdir($zip_stage);
    mkdir($zipfile_stage);
    mkdir("$zip_stage/$pt_objid");
    mkdir("$zipfile_stage/$pt_objid");

    # don't compress jp2, tif, etc..
    my $uncompressed_extensions = join(":",@{ $volume->get_nspkg()->get('uncompressed_extensions') });
    # add the necessary flag for zip if we have any uncompressed extensions
    $uncompressed_extensions = "-n $uncompressed_extensions" if($uncompressed_extensions);

    my @files = @{ $volume->get_all_content_files() };
    my $source_mets = $volume->get_source_mets_file();
    push(@files, basename($volume->get_source_mets_file())) if $source_mets;

    foreach my $file (@files) {
        if(! -e "$stage/$file") {
            $self->set_error('MissingFile',file => "$stage/$file");
        }

        if(!symlink("$stage/$file","$zip_stage/$pt_objid/$file"))
        {
            $self->set_error('OperationFailed',operation=>'symlink',file => "$stage/$file",detail=>"Symlink to staging directory failed: $!");
        }
    }

    my $zip_path = $volume->get_zip_path();

    $self->zip($zip_stage,$uncompressed_extensions,$zip_path,$pt_objid) or return;

    $self->_set_done();
    $volume->record_premis_event('zip_compression');
    return $self->succeeded();
}

=item zip()

    $self->zip($zip_staging_dir,$other_options,$zip_file_path,$pt_objid)

=cut

sub zip{
    my $self = shift;
    my ($zip_stage,$other_options,$zip_path,$pt_objid) = @_;

    get_logger()->trace("Packing $zip_stage/$pt_objid to $zip_path");
    my $zipret = system("cd '$zip_stage'; zip -q -r $other_options '$zip_path' '$pt_objid'");

    if($zipret) {
        $self->set_error('OperationFailed',operation=>'zip',detail=>'Creating zip file',exitstatus=>$zipret,file=>$zip_path);
        return;
    } else {

        $zipret = system("unzip -qq -t '$zip_path'");

        if($zipret) {
            $self->set_error('OperationFailed',operation=>'unzip',exitstatus=>$zipret,file=>$zip_path,detail=>'Verifying zip file');
            return;
        }        
    }

    # success
    get_logger()->trace("Packing $zip_stage/$pt_objid to $zip_path succeeded");
    return 1;
}

=item stage_info()

return stage info (success/failure)

=cut

sub stage_info{
    return {success_state => 'packed', failure_state => ''};
}

=item clean_always()

Perform cleaning that is appropriate on completion of this stage

=cut

sub clean_always{
    my $self = shift;
    my $pt_objid = $self->{volume}->get_pt_objid();
    my $zip_stage = get_config('staging','zip');
    
    get_logger()->trace("Removing $zip_stage/$pt_objid");
    remove_tree "$zip_stage/$pt_objid";
}


=item clean_failure()

Perform cleaning that is appropriate on stage failure

=cut

sub clean_failure{
    my $self = shift;
    my $pt_objid = $self->{volume}->get_pt_objid();
    my $zipfile_stage = get_config('staging'=>'zipfile');
    
    get_logger()->trace("Removing $zipfile_stage/$pt_objid");
    remove_tree "$zipfile_stage/$pt_objid";    
}

1;

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
