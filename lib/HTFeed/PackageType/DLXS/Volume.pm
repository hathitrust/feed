package HTFeed::PackageType::DLXS::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::PackageType::MPubDCU::Volume;
use HTFeed::Config;

my %pagetag_map = (
    APP => 'APPENDIX',
    BIB => 'BIBLIOGRAPHY',
    CTP => 'TITLE',
    IND => 'INDEX',
    LOI => 'LIST_OF_ILLUSTRATION',
    LOT => 'LIST_OF_MAPS',
    NOT => 'NOTES',
    PRE => 'PREFACE',
    PRF => 'PREFACE',
    REF => 'REFERENCES',
    TOC => 'TABLE_OF_CONTENTS',
    TPG => 'TITLE',
    VLI => 'LIST_OF_ILLUSTRATION',
    VTP => 'TITLE',
    VTV => 'TITLE',

);

sub get_srcmets_page_data {
    my $self = shift;
    my $file = shift;

    (my $seqnum) = ($file =~ /(\d+)\./);
    croak("Can't extract sequence number from file $file") unless $seqnum;

    if(not defined $self->{'page_data'}) {
        my $pagedata = {};

        my $pageview = $self->get_preingest_directory() . "/pageview.dat";
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

sub get_page_data {
    my $self = shift;
    my $file = shift;

    (my $seqnum) = ($file =~ /(\d+)\./);
    croak("Can't extract sequence number from file $file") unless $seqnum;

    if(not defined $self->{'page_data'}) {
        my $pagedata = {};

        my $xc = $self->get_source_mets_xpc();
        foreach my $page ($xc->findnodes('//METS:structMap/METS:div/METS:div')) {
            my $order = sprintf("%08d",$page->getAttribute('ORDER'));
            my $detected_pagenum = $page->getAttribute('ORDERLABEL');
            my $tag = $page->getAttribute('LABEL');
            if (defined $tag) {
                $tag = $pagetag_map{$tag};
            }
            $pagedata->{$order} = {
                orderlabel => $detected_pagenum,
                label => $tag
            }
        }
        $self->{page_data} = $pagedata;
    }

    return $self->{page_data}{$seqnum};
}

# no download location to clean for this material

sub get_download_location {
    return;
}

sub get_loadcd_info {
    my $self = shift;
    my $loadcd_file = join('/',$self->get_preingest_directory(),"loadcd.log");
    if(!-e $loadcd_file) {
        return { volume_id => undef, load_date => undef };
    }
    open(my $loadcd_fh, "<", $loadcd_file) or $self->set_error("UnexpectedError", file=>$loadcd_file, detail => "Can't open file: $!");

    my $header = <$loadcd_fh>;
    chomp $header;
    if($header =~ /loaded from volume ID (\w+) on (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/) {
        return { volume_id => $1,
                 load_date => $2 };
    } else {
        $self->set_error("BadFile",file=>$loadcd_file,detail=>"Can't parse header",actual=>$header);
    }
}


1;


__END__
