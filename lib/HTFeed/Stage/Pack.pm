package HTFeed::Stage::Pack;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use File::Basename qw(basename);
use File::Path qw(remove_tree);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

# return estimated space needed on ramdisk
sub ram_disk_size{
    my $self = shift;
    my $volume = $self->{volume};

    my $dir = $volume->get_staging_directory();
    
    return dir_size($dir);
}

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $pt_objid = $volume->get_pt_objid();
    my $stage = $volume->get_staging_directory();

    my @files_to_zip = ();

    # Make a temporary staging directory
	#XXX update get_config('staging')?
    my $zip_stage = get_config('staging','zip');
    mkdir($zip_stage);
    mkdir("$zip_stage/$pt_objid");

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
            $self->set_error('OperationFailed',operation=>'symlink',file => "$stage/$file",description=>"Symlink to staging directory failed: $!");
        }
    }

    my $zip_path = $volume->get_zip_path();
    my $zipret = system("cd '$zip_stage'; zip -q -r $uncompressed_extensions '$zip_path' '$pt_objid'");

    if($zipret) {
        $self->set_error('OperationFailed',operation=>'zip',detail=>'Creating zip file',exitstatus=>$zipret,file=>$zip_path);
    } else {

        $zipret = system("unzip -q -t $zip_path");

        if($zipret) {
            $self->set_error('OperationFailed',operation=>'unzip',exitstatus=>$zipret,file=>$zip_path,detail=>'Verifying zip file');
        }

    }



    $self->_set_done();
    $volume->record_premis_event('zip_compression');
    return $self->succeeded();
}

sub stage_info{
    return {success_state => 'packed', failure_state => ''};
}

sub clean_always{
    my $self = shift;
    my $pt_objid = $self->{volume}->get_pt_objid();
	#XXX update get_config('staging')?
    my $zip_stage = get_config('staging','zip');
    
    remove_tree "$zip_stage/$pt_objid";
}

1;

__END__
