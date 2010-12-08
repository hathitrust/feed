package HTFeed::Stage::Sample;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use File::Copy;
use Time::localtime;
use File::Path qw(make_path remove_tree);
use IO::File;

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $identifier = $volume->get_identifier();
    
    my $staging_dir = $volume->get_staging_directory();

    # get images
    my $file_groups = $volume->get_file_groups();
    # make sure there are images
    if( ! exists $file_groups->{image} ){
        # no images here, skip sampling
        $logger->debug("Sample: Zero images found for $identifier");
        $self->_set_done();
        return $self->succeeded();
    }
    my $images = $file_groups->{image}->get_filenames();
    
    # decide which pages we want
    my $total_pages = scalar (@$images);
    my $sample_pages = 20;
    my $start_page = 0;
    if ($total_pages > $sample_pages){
        $start_page = rand() * ($total_pages - $sample_pages);
        $start_page = sprintf("%d",$start_page);
    }
    my $finish_page = $start_page + $sample_pages - 1;
    $finish_page = ($total_pages - 1) if ($finish_page > ($total_pages - 1));
    
    # make sure $sample_directory exists and is empty
    my $date = get_date();
    my $sample_directory = sprintf("%s/%s/%s", get_config('sample_directory'), $date, $objid);
    if (-e $sample_directory){
        remove_tree $sample_directory;
    }
    make_path $sample_directory;
    
    # open csv writer
    my $csv = IO::File->new( "> $sample_directory/$objid.csv" );
    
    # copy each page
    foreach my $i ($start_page..$finish_page){
        my $image_name = "$images->[$i]";
        copy ("$staging_dir/$image_name","$sample_directory/$image_name");
        
        # write a line in the csv
        $image_name =~ /([^\.]*)\.(.*)/;
        print $csv "$objid,$1,$2\n"; # objid,file name,extension
    }
    
    # close csv
    $csv->close(); 
    
    # TODO: check, set errors
    
    $self->_set_done();
    return $self->succeeded();
}

sub stage_info{
    return {success_state => 'sampled', failure_state => 'punted', failure_limit => 1};
}

sub get_date {

	my $now = localtime();
	
	my $date = sprintf("%04d-%02d-%02d",
					   (1900 + $now->year()),
					   (1 + $now->mon()),
					   $now->mday());

	return($date);
}


1;

__END__
