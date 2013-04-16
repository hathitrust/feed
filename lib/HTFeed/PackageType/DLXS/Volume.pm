package HTFeed::PackageType::DLXS::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::PackageType::MPub::Volume;
use HTFeed::Config;
use Roman qw(roman);

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

my $INHOUSE = 'University of Michigan Digital Conversion Unit';
my $UNKNOWN = undef;
my $PR = 'Preservation Resources';
my $TRIGO = 'Trigonix'; 

# Map from CD label / project codes to scanning artist.
# From ldunger 'CD_Label_explanations.xls'
my %volume_id_map = (
    ACLS => $UNKNOWN,
    BEN => $INHOUSE,
    BVBE => $INHOUSE,
    CC => $UNKNOWN,
    CLCH => $UNKNOWN,
    COLD => 'University of Michigan or Trigonix',
    DENT => $INHOUSE,
    DE => $TRIGO,
    ESU => $UNKNOWN,
    FISH => 'University of Michigan or Trigonix',
    GLRD => $UNKNOWN,
    JWA => $UNKNOWN,
    MAA => 'DI (Mexico)',
    MA => $INHOUSE,
    MFM => $UNKNOWN,
    MID => 'Penny Imaging',
    MM => $UNKNOWN,
    MOA4 => $UNKNOWN,
    MOA5 => $PR,
    MQR => $TRIGO,
    MUTECH => $UNKNOWN,
    NEH => $TRIGO,
    NEHZ => $INHOUSE,
    NICK => 'Kirtas Technologies',
    NSF => 'DI (Mexico)',
    PA => 'ACME Bookbinding',
    PB => 'Backstage Libraryworks',
    PBBI => $INHOUSE,
    PBCT => $INHOUSE,
    PC => 'ICI Bookbinding',
    PD => $INHOUSE,
    PE => 'ICI Bookbinding',
    PF => $INHOUSE,
    PH => $PR,
    PHZ => $INHOUSE,
    PI => 'Penny Imaging',
    PN => $UNKNOWN,
    PORT => $PR,
    PP => $PR,
    PRA => 'ACME Bookbinding',
    PRGS => 'Graphic Science',
    PRPR => $PR,
    PS08 => $INHOUSE,
    PT => 'Trigonix',
    PX => $INHOUSE,
    PZ => $INHOUSE,
    REGENTS => $UNKNOWN,
    UMMU => $UNKNOWN,
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
                next if $line =~ /^\s*#/; # skip comments
                # clear line endings
                $line =~ s/[\r\n]//;
                my(undef,$order,$detected_pagenum,undef,$tags) = split(/\t/,$line);
                $detected_pagenum =~ s/^0+//; # remove leading zeroes from pagenum
                if($detected_pagenum =~ /^R(\d{3})$/i) {
                    $detected_pagenum = roman($1);
                }
                if (defined $tags) {
                    $tags = join(', ',split(/\s/,$tags));
                }

                $order = '0000' . $order if $order =~ /^\d{4}$/;

                $pagedata->{$order} = {
                    orderlabel => $detected_pagenum,
                    label => $tags
                }
            }
            $self->{page_data} = $pagedata;
        }
    }

    $self->set_error("MissingField",field => "page_data", file => $seqnum, 
        detail => "No page data found for seq=$seqnum") 
        if not defined $self->{page_data}{$seqnum};
    return $self->{page_data}{$seqnum};
}

sub get_page_data {
    my $self = shift;
    my $file = shift;

    (my $seqnum) = ($file =~ /(\d+)\./);
    croak("Can't extract sequence number from file $file") unless $seqnum;

    if(not defined $self->{'page_data'}) {
        $self->record_premis_event('page_feature_mapping');
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
    if($header =~ /loaded from volume ID ([\w#]+) on (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/) {
        my $volume_id = $1;
        my $load_date = $2;
        my $artist = undef;;
        if($volume_id =~ /^([a-z0-9]+)_/i) {

            my $project_id = $1;
            if(defined($volume_id_map{uc($project_id)})) {
                $artist = $volume_id_map{uc($project_id)};
            } elsif($volume_id = /^([a-z]+)/i and 
               defined($volume_id_map{uc($1)})) {
                $artist = $volume_id_map{uc($1)};
            }
        }
        return { volume_id => $1,
                 load_date => $2, 
                 artist => $artist,
             };
    } else {
        $self->set_error("BadFile",file=>$loadcd_file,detail=>"Can't parse header",actual=>$header);
    }
}


1;


__END__
