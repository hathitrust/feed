#!/usr/bin/perl
package HTFeed::PackageType::Audio::Volume;

use warnings;
use strict;
use HTFeed::Volume;
use base qw(HTFeed::Volume);

sub get_download_location {
    # don't try to remove anything on clean
    return undef;

}

sub get_audio_files {

	my $self = shift;
	if(not defined $self->{audio_files}) {
		foreach my $filegroup (values(%{ $self->get_file_groups()})) {
			push(@{ $self->{audio_files} },@{$filegroup->get_filenames() }) if ($filegroup->{archival} || $filegroup->{preservation});
		}
	}

	return $self->{audio_files};
}

1;
