package HTFeed::Stage::Pack;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use File::Basename qw(basename);
use File::Path qw(remove_tree);
use Cwd qw(getcwd);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $path = $volume->get_staging_directory();

    my @files_to_zip = ();

    # Make a temporary staging directory
    my $old_dir = getcwd();
    my $zip_stage = get_config('staging','zip');
    mkdir($zip_stage);
    chdir($zip_stage) or die("Can't use $zip_stage directory");
    mkdir("$objid");

    # Add OCR files with compression
    my $uncompressed_extensions = join(":",@{ $volume->get_nspkg()->get('uncompressed_extensions') });
    my @files = @{ $volume->get_all_content_files() };
    push(@files, basename($volume->get_source_mets_file()));

    foreach my $file (@files) {
	if(! -e "$path/$file") {
	    $self->set_error('MissingFile',file => "$path/$file");
	}

	if(!symlink("$path/$file","$objid/$file"))
	{
	    $self->set_error('OperationFailed',operation=>'symlink',file => "$path/$file",description=>"Symlink to staging directory failed: $!");
	}

    }

    my $working_dir = get_config('staging'=>'memory');
    my $zipret = system("zip -q -r -n $uncompressed_extensions $working_dir/$objid.zip $objid");

    if($zipret) {
	    $self->set_error('OperationFailed',operation=>'zip',detail=>'Creating zip file',exitstatus=>$zipret,file=>"$working_dir/$objid.zip");
    } else {

        $zipret = system("unzip -q -t $working_dir/$objid.zip");

        if($zipret) {
            $self->set_error('OperationFailed',operation=>'unzip',exitstatus=>$zipret,file=>"$working_dir/$objid.zip",detail=>'Verifying zip file');
	    }

    }

    chdir($old_dir) or die("Can't chdir to $old_dir: $!");


    $self->_set_done();
    $volume->record_premis_event('zip_compression');
    return $self->succeeded();
}

sub clean_always{
    my $self = shift;
    my $objid = $self->{volume}->get_objid();
    my $zip_stage = get_config('staging','zip');
    
    remove_tree "$zip_stage/$objid";
}

1;

__END__
