package HTFeed::PackageType::Simple::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::Config;
use YAML::Any qw(LoadFile);

# front for YAML file

# get yaml meta.xml

sub get_meta {
    my $self = shift;
    my $key = shift;

    if(not defined $self->{meta_yml}) {
        my $preingest = $self->get_preingest_directory();
        my $yaml = LoadFile("$preingest/meta.yml");
        $self->{meta_yml} = $yaml if defined $yaml;
    }

    my $value = $self->{meta_yml}{$key};
    return if not defined $value;
    # accept TIFF-format type dates
    if($key =~ /date/) {
        $value =~ s/^(\d{4}).(\d{2}).(\d{2}).(\d{2}).(\d{2}).(\d{2})/$1-$2-$3T$4:$5:$6/;
    }

    return $value;
}

# get pagedata - from yaml

sub get_srcmets_page_data {

    my $self = shift;
    my $file = shift;

    if(not defined $self->{'page_data'}) {
        my $yaml_pagedata = $self->get_meta('pagedata');
        my $pagedata = {};
        # change filenames to sequence numbers
        while (my ($k,$v) = each(%$yaml_pagedata)) {
            $k =~ /(\d{8})\.\w{3}$/ or croak("Bad filename $k in meta.yml pagedata");
            $pagedata->{$1} = $v;
        }
        $self->{page_data} = $pagedata;
    }

    if(defined $file) {
        (my $seqnum) = ($file =~ /(\d+)\./);
        croak("Can't extract sequence number from file $file") unless $seqnum;

        # ok if no page data for that seq
        return $self->{page_data}{$seqnum};
    }
}

sub get_checksums{
    my $self = shift;

    # if source METS exists, use that; otherwise, use checksum.md5
    my $src_mets = $self->get_source_mets_file();
    if(defined $src_mets) {
        return $self->get_checksum_mets();
    } else {
        return $self->get_checksum_md5($self->get_preingest_directory());
    }

}

1;

__END__
