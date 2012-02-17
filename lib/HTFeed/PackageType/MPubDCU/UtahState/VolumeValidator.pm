package HTFeed::PackageType::MPubDCU::UtahState::VolumeValidator;

use strict;
use HTFeed::PackageType::MPubDCU::Volume;
use Carp;
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);
use base qw(HTFeed::VolumeValidator);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{stages}{validate_image_consistency} = \&_check_for_dupes;
    return $self;
}

sub _check_for_dupes {

	# complain if a tif and jp2 exist for the same page 

	my @list;
	my %count;
	my $prefix;
	my $suffix;

	my $self = shift;
	my $volume = $self->{volume};
	my $objid = $volume->get_objid();

	my $files = $volume->get_all_directory_files();

	foreach my $file(@$files){
		if($file =~ /(\d+)\.(\w\w\w)$/){
            $prefix = $1;
			$suffix = $2;
		}
		next unless($suffix eq "tif" || $suffix eq "jp2");
		push(@list, $prefix);
	}

	map { $count{$_}++ } @list;

	foreach (sort { $a <=> $b } keys(%count) ) {
		if($count{$_} eq 2){
			$self->set_error("BadFile", detail=>"conflicting jp2 and tif exist for page $_");
		}
	}

	return;

}




1;
