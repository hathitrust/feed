package HTFeed::PackageType::DLXS::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::PackageType::MPub::Volume;
use HTFeed::Config;
use Roman qw(roman);
use File::Basename;
use Carp qw(croak);

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

# get mapping from original sequence numbers to corrected filenames
sub get_seq_mapping {
    my $self = shift;

    if(not defined $self->{'seq_mapping'}) {
        # parse pageview.dat
        $self->get_srcmets_page_data();
    }

    return $self->{'seq_mapping'};

}

sub get_srcmets_page_data {
    my $self = shift;
    my $file = shift;

    if(not defined $self->{'page_data'}) {
        my $pagedata = {};
        my $seq_mapping = {};
        # seq in pageview.dat can have skips in it; we create a mapping
        # from the old filenames/sequence numbers to a sequence starting at
        # 00000001 with no gaps in it.
        my $new_seq = '00000000';

        my $pageview = $self->get_preingest_directory() . "/pageview.dat";
        if(-e $pageview) {
            open(my $pageview_fh,"<$pageview") or croak("Can't open pageview.dat: $!");
            <$pageview_fh>; # skip first line - column headers

            my $prev_old_seq;
            my $prev_detected_pagenum;
            while(my $line = <$pageview_fh>) {
                next if $line =~ /^\s*#/; # skip comments
                next if $line =~ /^\s*$/; # skip blank lines
                $new_seq++;
                # clear line endings
                $line =~ s/[\r\n]//;
                my($file,$old_seq,$detected_pagenum,undef,$tags) = split(/\s+/,$line);

                if($file !~ /^$old_seq/) {
                    $self->set_error("NotEqualValues",field=> "page_data", file => $pageview,
                        expected => $old_seq, actual => $file, detail => "Mismatched filename and seqnum");
                }

                $detected_pagenum =~ s/^0+//; # remove leading zeroes from pagenum
                if($detected_pagenum =~ /^R(\d{3})$/i) {
                    $detected_pagenum = roman($1);
                }
                if (defined $tags) {
                    $tags = join(', ',split(/\s/,$tags));
                }

                $old_seq = '0000' . $old_seq if $old_seq =~ /^\d{4}$/;
                $new_seq = sprintf("%08d",$new_seq);

                $pagedata->{$new_seq} = {
                    orderlabel => $detected_pagenum,
                    label => $tags
                };

                $seq_mapping->{$old_seq} = $new_seq;

                if($self->should_check_validator('sequence_skip')) {
                    # if there was a skip in the sequence, was there a skip 
                    # in the page numbers?
                    if(defined $prev_old_seq and $old_seq != $prev_old_seq + 1) {
                        unless (defined $detected_pagenum 
                                and defined $prev_detected_pagenum
                                and $detected_pagenum =~ /^\d+$/
                                and $prev_detected_pagenum =~ /^\d+$/
                                and $prev_detected_pagenum + 1 == $detected_pagenum) {

                            # not legitimate skip: one or the other side has no
                            # page number, or page numbers are not sequential
                            $prev_detected_pagenum = '' if not defined $prev_detected_pagenum;
                            $detected_pagenum = '' if not defined $detected_pagenum;
                            $self->set_error("BadValue",field=>"page_data",file=>$pageview,
                                detail => "Sequence skip between seq=$prev_old_seq/page='$prev_detected_pagenum' and seq=$old_seq/page='$detected_pagenum'");

                        }
                    }
                }


                $prev_old_seq = $old_seq;
                $prev_detected_pagenum = $detected_pagenum;

            }
            $self->{page_data} = $pagedata;
            $self->{seq_mapping} = $seq_mapping;
        }
    }


    if(defined $file) {
        (my $seqnum) = ($file =~ /(\d+)\./);
        croak("Can't extract sequence number from file $file") unless $seqnum;

        $self->set_error("MissingField",field => "page_data", file => $seqnum, 
            detail => "No page data found for seq=$seqnum") 
            if not defined $self->{page_data}{$seqnum};
        return $self->{page_data}{$seqnum};
    }

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

# MOA material uses a scheme of MMMMNNNN.ext for file naming where MMMM is the
# sequence number and NNNN is the zero-padded detected page number, or RNNN for
# roman numeral page numbers.
sub has_moa_filenames {
    my $self = shift;

    if(not defined $self->{moa_filenames}) {
        my $preingest_path = $self->get_preingest_directory();
        my @tiffs = map { basename($_) } glob("$preingest_path/[0-9]*.tif");
        my $first = (sort(@tiffs))[0];
        if ($first =~ /^0001/) {
            $self->{moa_filenames} = 1;
        } else {
            $self->{moa_filenames} = 0;
        }
    }

    return $self->{moa_filenames};
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

# return true if we should do particular validation checks - false if we're
# using the 'note from mom' for that check or disabling validation for this volume
sub should_check_validator {
    my $self = shift;

    my $validator = shift;

    # TODO: handle note from mom
    
    my @skip_validation = @{$self->get_nspkg()->get('skip_validation')};

    if(grep {$_ eq $validator} @skip_validation) {
        return 0;
    } else {
        return 1;
    }
}


1;


__END__
