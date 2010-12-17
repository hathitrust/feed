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

	my $xc = $self->get_source_mets_xpc();

	foreach my $pagenode ($xc->findnodes('//METS:techMD/book/pageData/page')) {
	    my $leafnum = $pagenode->getAttribute('leafNum');
	    my $seqnum_padded = sprintf("%08d",$leafnum);
	    my $detected_pagenum = $xc->findvalue('./pageNumber',$pagenode);
	    my $hand_side = $xc->findvalue('./handSide',$pagenode);
	    my $page_type = $xc->findvalue('./pageType',$pagenode);

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

1;

__END__
