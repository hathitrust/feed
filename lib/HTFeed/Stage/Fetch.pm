package HTFeed::Stage::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);

sub fetch_from_source {

	my $self = shift;
	my $source = shift;
	my $dest = shift;

	if(! -e $dest) {
		mkdir $dest or die("Can't mkdir $dest $!");
	}
	
	system("cp -rs '$source' '$dest'")
        and $self->set_error('OperationFailed', operation=>'copy', detail=>"copy $source $dest failed with status: $?");
}

sub fix_line_endings {
    my $self = shift;
    my $base = shift;
	my $volume = $self->{volume};
	my $objid = $volume->get_objid();

	my $dir = "$base/$objid";

    foreach my $filename (glob("$dir/*.txt"), "$dir/checksum.md5", "$dir/pageview.dat") {

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

}

sub stage_info{
	return {success_state => 'fetched', failure_state => 'punted'};
}

1;
