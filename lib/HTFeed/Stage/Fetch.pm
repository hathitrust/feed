package HTFeed::Stage::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage::DirectoryMaker);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);

sub fetch_from_source {

	my $self = shift;
	my $source = shift;
	my $dest = shift;

	if(! -e $dest) {
		mkdir $dest or die("Can't mkdir $dest $!");
	}
	
    get_logger()->trace("Fetching from source: cp -Lrs '$source' '$dest'");
	system("cp -Lrs '$source' '$dest'")
        and $self->set_error('OperationFailed', operation=>'copy', detail=>"copy $source $dest failed with status: $?");
}

sub fix_line_endings {
    my $self = shift;
    my $base = shift;
	my $volume = $self->{volume};
	my $objid = $volume->get_objid();

	my $dir = "$base/$objid";

    foreach my $filename (glob("$dir/*.txt"), "$dir/checksum.md5", "$dir/pageview.dat") {
        next unless -e $filename;

        if( -e "$filename.bak" ) {
            $self->set_error("UnexpectedError","$filename.bak exists");
        }
        
        rename("$filename","$filename.bak") or $self->set_error("OperationFailed",operation => "rename",file => $filename,detail => $!);
        open INPUT, "$filename.bak" or $self->set_error("OperationFailed",operation => "open", file => "$filename.bak", detail => $!);
        open OUTPUT, ">$filename" or $self->set_error("OperationFailed",operation => "open", file => "$filename", detail => $!);

        while( <INPUT> ) {
            s/\r\n$/\n/;     # convert CR LF to LF
            print OUTPUT $_;
        }

        close INPUT;
        close OUTPUT;
        unlink("$filename.bak") or $self->set_error("OperationFailed",operation => "unlink", file => "$filename.bak", detail => $!);
        get_logger()->trace("Cleaned line endings for $filename");

    }

}

sub stage_info{
	return {success_state => 'fetched', failure_state => 'punted'};
}

1;
