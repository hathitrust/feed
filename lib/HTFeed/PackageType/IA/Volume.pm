package HTFeed::PackageType::IA::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Config qw(get_config);
use File::Pairtree;
use File::Path qw(make_path);

my $pagetag_mapping = {
    'Blank Tissue' => 'BLANK',
    'Chapter' => 'CHAPTER_START',
    'Contents' => 'TABLE_OF_CONTENTS',
    'Copyright' => 'COPYRIGHT',
    'Cover' => 'COVER',
    'Foldout' => 'FOLDOUT',
    'Illustration' => 'IMAGE_ON_PAGE',
    'Illustrations' => 'IMAGE_ON_PAGE',
    'Index' => 'INDEX',
    'Tissue' => 'BLANK',
    'Title' => 'TITLE',
    'Title Page' => 'TITLE'
};

sub get_ia_id{
    my $self = shift;

    my $ia_id = $self->{ia_id};
    # return it if we have it
    if ($ia_id){
        return $ia_id;
    }

    # else get it and memoize
    my $arkid = $self->get_objid();

    my $dbh = get_dbh();
    my $sth = $dbh->prepare("select ia_id from ia_arkid where arkid = ?");
    $sth->execute($arkid);

    my $results = $sth->fetchrow_arrayref();

    #TODO make this work if db result is null
    $ia_id = $results->[0];

    $self->{ia_id} = $ia_id;
    return $ia_id;
}

sub get_page_data {
    my $self = shift;
    my $file = shift;

    (my $seqnum) = ($file =~ /(\d+)/);
    croak("Can't extract sequence number from file $file") unless $seqnum;

    if(not defined $self->{'page_data'}) {
        $self->record_premis_event('page_feature_mapping');
        my $pagedata = {};
        my $ia_pagedata = {};

        my $xpc = $self->get_source_mets_xpc();
        $xpc->registerNs('scribe','http://archive.org/scribe/xml');

        # may appear with or without namespace..
        foreach my $pagenode ($xpc->findnodes('//METS:techMD/METS:mdWrap/METS:xmlData/book/pageData/page'),
                              $xpc->findnodes('//METS:techMD/METS:mdWrap/METS:xmlData/scribe:book/scribe:pageData/scribe:page')) {
            my $leafnum = $pagenode->getAttribute('leafNum');
            my $seqnum_padded = sprintf("%08d",$leafnum);
            my $detected_pagenum = $xpc->findvalue('./pageNumber | ./scribe:pageNumber',$pagenode);
            my $hand_side = $xpc->findvalue('./handSide | ./scribe:handside',$pagenode);
            my $page_type = $xpc->findvalue('./pageType | ./scribe:pageType',$pagenode);

            my $mapped_page_type = $pagetag_mapping->{$page_type};
            my @tags = ();
            push(@tags,$hand_side) if defined $hand_side;
            push(@tags,$mapped_page_type) if defined $mapped_page_type;

            $pagedata->{$seqnum_padded} = {};
            $pagedata->{$seqnum_padded}{orderlabel} = $detected_pagenum if defined $detected_pagenum;
            $pagedata->{$seqnum_padded}{label} = join(", ",@tags) if @tags;

        }

        $self->{page_data} = $pagedata;
    }

    return $self->{page_data}{$seqnum};
}

sub get_download_directory {
    my $self = shift;
    my $ia_id = $self->get_ia_id();
    my $path = get_config('staging'=>'download');
    my $pt_path = "$path/ia/" . id2ppath($ia_id);
    make_path($pt_path) unless -e $pt_path;
    return $pt_path;
}

sub get_preingest_directory {
    my $self = shift;

    my $arkid = $self->get_objid();
    return sprintf("%s/%s", get_config('staging'=>'preingest'), s2ppchars($arkid));
}

sub get_scandata_xpc {
    my $self = shift;
    if(not defined $self->{scandata_xpc}) {
        my $path = $self->get_download_directory();
        my $ia_id = $self->get_ia_id();

        my $xpc = $self->_parse_xpc("$path/${ia_id}_scandata.xml");
        $xpc->registerNs('scribe','http://archive.org/scribe/xml');
        $self->{scandata_xpc} = $xpc;

    }
    return $self->{scandata_xpc};
}

sub get_download_location {
    my $self = shift;
    # IA has multiple files in SIP
    return $self->get_download_directory();
}

1;

__END__
