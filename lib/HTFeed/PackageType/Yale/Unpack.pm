package HTFeed::PackageType::Yale::Unpack;

use warnings;
use strict;
use IO::Handle;
use IO::File;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    
    my $download_dir = $volume->get_download_directory();
    my $preingest_dir = get_config('staging'=>'preingest');
    my $objid = $volume->get_objid();
    
    my $infile = sprintf("%s/%s.zip",$download_dir,$objid);
    my $outdir = $preingest_dir;
    
    my $file = sprintf("%s/%s.zip",$download_dir,$objid);
    # check that file exists
    if (-e $file){
        $logger->trace("Unpacking $file");

	# make directory
	unless( -d $outdir or mkdir $outdir, 0770 ){
	    $self->set_error('OperationFailed',operation=>'mkdir',detail=>"$outdir could not be created");
	    return;
	}
	
	# unzip - not using Archive::Zip because it's broken on zip64..
	my $cmd = "yes 'n' | unzip -o -q '$infile' -d '$outdir'";
	my $rstring = `$cmd`;
	my $rval = $?;
	if($rval or $rstring) {
	    $self->set_error('OperationFailed',operation=>'unzip',exitstatus=>$rval,detail=>$rstring);
	    return;
	}

	$logger->debug("$infile unzipped");
    
    }
    else{
        $self->set_error('MissingFile',file=>$file);
        return;
    }
    
    
    $self->_set_done();
    return $self->succeeded();
}


1;

__END__