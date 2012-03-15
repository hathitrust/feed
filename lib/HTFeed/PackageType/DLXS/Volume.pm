package HTFeed::PackageType::DLXS::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::PackageType::MPubDCU::Volume;
use HTFeed::Config;

# don't pt-escape the directory name for preingest for these (following dlxs conventions)
sub get_preingest_directory {
    my $self = shift;
    my $ondisk = shift;

    my $objid = $self->get_objid();
    return sprintf("%s/%s", get_config('staging'=>'disk'=>'preingest'), $objid) if $ondisk;
    return sprintf("%s/%s", get_config('staging'=>'preingest'), $objid);
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

# no download location to clean for this material

sub get_download_location {
    return;
}


1;


__END__
