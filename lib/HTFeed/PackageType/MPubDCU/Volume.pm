package HTFeed::PackageType::MPubDCU::Volume;

use warnings;
use strict;
use base qw(HTFeed::PackageType::DLXS::Volume);
use HTFeed::Config;

# no source METS expected for this content 

sub get_source_mets_xpc {
    return;
}

sub get_source_mets_file {
    return;
}

# use checksum.md5 instead of source METS
sub get_checksums{

	my $self = shift;
    my $path = $self->get_staging_directory();
    my $checksum_file = $self->get_nspkg()->get('checksum_file');
	my $checksum_path = "$path/$checksum_file";

	my $checksum;
	my $filename;

	if (not defined $self->{checksums} ){

		my $checksums = {};

		open(FILE, $checksum_path) or die $!;		
		foreach my $line(<FILE>) {
			$line =~ /(\w+)(\s{2})(\w+\.\w{3})/;
			$checksum = $1;
			$filename = $3;
			$checksums->{$filename} = $checksum;
		}	
		$self->{checksums} = $checksums;
	}
	close(FILE);
    return $self->{checksums};
}

# no preingest/remediation for this content
sub get_preingest_directory {
    return;
}


1;


__END__
