#!/usr/bin/perl
package HTFeed::PackageType::Audio::Volume;

use warnings;
use strict;
use HTFeed::Volume;
use base qw(HTFeed::Volume);
use Log::Log4perl qw(get_logger);

my $logger = get_logger(__PACKAGE__);


sub get_download_location {
    # don't try to remove anything on clean
    return undef;
}

sub get_file_groups_by_page {
    my $self = shift;
    my $filegroups      = $self->get_file_groups();
    my $files           = {};

    # First determine what files belong to each sequence number
    while ( my ( $filegroup_name, $filegroup ) =
        each( %{ $filegroups } ) )
    {
        foreach my $file ( @{$filegroup->get_filenames()} ) {
            if ( $file =~ /[ap]m\d{2,8}.(wav)$/ ) {
                my $sequence_number = $1;
                if(not defined $files->{$sequence_number}{$filegroup_name}) {
                    $files->{$sequence_number}{$filegroup_name} = [$file];
                } else {
                    push(@{ $files->{$sequence_number}{$filegroup_name} }, $file);
                }
            }
            else {
                warn("Can't get sequence number for $file");
            }
        }
    }

    return $files;

}

1;
