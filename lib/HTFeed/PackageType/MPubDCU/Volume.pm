package HTFeed::PackageType::MPubDCU::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::Config;

sub get_source_mets_xpc {
return;
}

sub get_checksums{

	my $self = shift;
	my $objid = $self->get_objid();
	my $objdir = get_config('staging' => 'ingest');
	my $checksum_file = "$objdir/$objid/checksum.md5";

	my $checksum;
	my $filename;

	if (not defined $self->{checksums} ){

		my $checksums = {};

		open(FILE, $checksum_file) or die $!;		
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

1;


__END__
