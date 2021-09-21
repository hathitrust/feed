package HTFeed::Stage::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage::DirectoryMaker);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);

=head1 NAME

HTFeed::Stage::Fetch

=item DESCRIPTION

Base class for HTFeed Fetch stage
Fetches new material for ingest from a networked location

=cut

=item fetch_from_source()

 fetch_from_source($source, $destination)
 fetches a package from directory $source
 and deposits it in directory $destination

=cut

sub fetch_from_source {

	my $self = shift;
	my $source = shift;
	my $dest = shift;

    # Make sure dest really exists and is a directory
	if(! -d $dest) {
		mkdir $dest or die("Can't mkdir $dest $!");
	}
	
    # -T forces $dest not to be treated specially because it is a directory
    # that already exists
    get_logger()->trace("Fetching from source: cp -LRT '$source/*' '$dest'");
	system("cp -LRT '$source' '$dest'")
        and $self->set_error('OperationFailed', operation=>'copy', detail=>"copy $source $dest failed with status: $?");
}

=item fix_line_endings()

fix_line_endings($destination)
Fixes line endings in text files
in directory $destination

=cut

sub fix_line_endings {
    my $self = shift;
    my $dir = shift;
	my $volume = $self->{volume};

    foreach my $filename (glob("$dir/*.txt"), glob("$dir/*.xml"), glob("$dir/*.html"), "$dir/checksum.md5", "$dir/pageview.dat") {
        next unless -e $filename;

        if( -e "$filename.bak" ) {
            $self->set_error("UnexpectedError","$filename.bak exists");
        }
        
        rename("$filename","$filename.bak") or $self->set_error("OperationFailed",operation => "rename",file => $filename,detail => $!);
        open INPUT, "$filename.bak" or $self->set_error("OperationFailed",operation => "open", file => "$filename.bak", detail => $!);
        open OUTPUT, ">$filename" or $self->set_error("OperationFailed",operation => "open", file => "$filename", detail => $!);

        while( <INPUT> ) {
            s/\r\n$/\n/;     # convert CR LF to LF
            s/\f//g; # strip out form feeds
            print OUTPUT $_;
        }

        close INPUT;
        close OUTPUT;
        unlink("$filename.bak") or $self->set_error("OperationFailed",operation => "unlink", file => "$filename.bak", detail => $!);
        get_logger()->trace("Cleaned line endings for $filename");

    }

}

=item stage_info()

Returns stage data based on success/failure

=cut

sub stage_info{
	return {success_state => 'fetched', failure_state => 'punted'};
}

1;
