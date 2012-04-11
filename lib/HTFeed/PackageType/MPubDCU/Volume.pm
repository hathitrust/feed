package HTFeed::PackageType::MPubDCU::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
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

sub get_page_data {
    my $self = shift;
    my $file = shift;

    (my $seqnum) = ($file =~ /(\d+)\./);
    croak("Can't extract sequence number from file $file") unless $seqnum;

    if(not defined $self->{'page_data'}) {
        my $pagedata = {};

        my $pageview = $self->get_staging_directory() . "/pageview.dat";
        if(-e $pageview) {
            open(my $pageview_fh,"<$pageview") or croak("Can't open pageview.dat: $!");
            <$pageview_fh>; # skip first line - column headers
            while(my $line = <$pageview_fh>) {
                # clear line endings
                $line =~ s/[\r\n]//;
                my(undef,$order,$detected_pagenum,undef,$tags) = split(/\t/,$line);
                $detected_pagenum =~ s/^0+//; # remove leading zeroes from pagenum
                if (defined $tags) {
                    $tags = join(', ',split(/\s/,$tags));
                }

                $pagedata->{$order} = {
                    orderlabel => $detected_pagenum,
                    label => $tags
                }
            }
            $self->{page_data} = $pagedata;
        }
    }

    return $self->{page_data}{$seqnum};
}

# no preingest/remediation for this content
sub get_preingest_directory {
    return;
}

# no download location to clean for this material

sub get_download_location {
    return;
}


1;


__END__
