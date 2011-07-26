package HTFeed::PackageType::MPubDCU::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);

sub run {

	my $self = shift;
	my $volume = $self->{volume};
	my $objid = $volume->get_objid();
	my $packagetype = $volume->get_packagetype();
	my $ns = $volume->get_namespace();
	my $fetch_dir = get_config('staging'=>'fetch');
	my $staging_dir = get_config('staging' => 'ingest');
	my $source = "$fetch_dir/$packagetype/forHT/$objid";

	if(! -e $staging_dir) {
		mkdir $staging_dir or die("Can't mkdir $staging_dir: $!");
	}
	
	system("cp -rs $source $staging_dir") 
        and $self->set_error('OperationFailed', operation=>'copy', detail=>"copy $source $staging_dir failed with status: $?");

    # fix line endings
    my $ingest_dir = $volume->get_staging_directory();
    foreach my $filename (glob("$ingest_dir/*.txt"), "$ingest_dir/checksum.md5") {
        next if( -e "$filename.bak" );
        next if(!( -f $filename && -r $filename && -w $filename  ));

        rename("$filename","$filename.bak");
        open INPUT, "$filename.bak";
        open OUTPUT, ">$filename";

        while( <INPUT> ) {
            s/\r\n$/\n/;     # convert CR LF to LF
            print OUTPUT $_;
        }

        close INPUT;
        close OUTPUT;
        unlink("$filename.bak");
        get_logger()->trace("Cleaned line endings for $filename");

    }

	$self->_set_done();
	return $self->succeeded();
}

sub stage_info{
	return {success_state => 'fetched', failure_state => 'punted'};
}

1;
