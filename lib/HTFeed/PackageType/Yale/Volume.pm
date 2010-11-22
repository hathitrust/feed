package HTFeed::PackageType::Yale::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::XMLNamespaces qw(:namespaces);
use List::MoreUtils qw(uniq);

=item get_page_data(file)

Returns a reference to a hash:

    { orderlabel => page number
      label => page tags }

for the page containing the given file.

If there is no detected page number or page tags for the given page,
the corresponding entry in the hash will not exist.

=cut

sub get_page_data {
    my $self = shift;
    my $file = shift;

    if ( not defined $self->{'page_data'} ) {
        $self->record_premis_event('page_feature_mapping');
	$self->{page_data} = $self->_extract_page_tags();
    }

    (my $seqnum) = ($file =~ /(\d+)/);
    croak("Can't extract sequence number from file $file") unless $seqnum;
    return $self->{'page_data'}{$seqnum};

}

my $type_map = {
    'app'          => 'APPENDIX',
    'backmatter'   => 'CHAPTER_START',
    'bibl'         => 'REFERENCES',
    'chapter'      => 'CHAPTER_START',
    'contents'     => 'TABLE_OF_CONTENTS',
    'copyright'    => 'COPYRIGHT',
# Either FRONT_COVER or BACK_COVER depending on position in book - see below
    'cover'        => '??_COVER',
    'diagram'      => 'IMAGE_ON_PAGE',
# Either PREFACE or CHAPTER_START depending on position in book - see below
    'frontmatter'  => '??_PREFACE',
    'ill'          => 'IMAGE_ON_PAGE',
    'illustration' => 'IMAGE_ON_PAGE',
    'index'        => 'INDEX',
    'intro'        => '??_PREFACE',
    'map'          => 'MAP',
    'notes'        => 'NOTES',
    'preface'      => 'PREFACE',
    'section'      => 'CHAPTER_START',
    'title'        => 'TITLE'
};

my $label_map = {
    qr/^Appendi.*/i         => 'APPENDIX',
    qr/^Advert.*/i          => 'ADVERTISEMENTS',
    qr/^Back Cover$/i       => 'BACK_COVER',
    qr/^Back Matter$/i      => 'CHAPTER_START',
    qr/^Bibliography$/i     => 'REFERENCES',
    qr/^Body$/i             => 'FIRST_CONTENT_CHAPTER_START',
    qr/^Book title$/i       => 'TITLE',
    qr/^Chap.*$/i           => 'CHAPTER_START',
    qr/^Conclusion$/i       => 'CHAPTER_START',
    qr/^Contents$/i         => 'TABLE_OF_CONTENTS',
    qr/^Copyright$/i        => 'COPYRIGHT',
    qr/^Cover$/i            => '??_COVER',
    qr/^Errata$/i           => 'ERRATA',
    qr/^Fold.*$/i           => 'FOLDOUT',
    qr/^Foreward.*$/i       => 'PREFACE',
    qr/^Front Cover.*$/i    => 'FRONT_COVER',
    qr/^Front Matter.*$/i   => '??_PREFACE',
    qr/\bIndex\b/i          => 'INDEX',
    qr/^Introduct.*/i       => '??_PREFACE',
    qr/^List of.*Plates.*/i => 'LIST_OF_PLATES',
    qr/^List of.*Illus.*/i  => 'LIST_OF_ILLUSTRATIONS',
    qr/^List of.*Map.*/i    => 'LIST_OF_MAPS',
    qr/^Map.*/i             => 'MAP',
    qr/^Notes$/i            => 'NOTES',
    qr/^Part .*/i           => 'CHAPTER_START',
    qr/^Preface$/i          => 'PREFACE',
    qr/^References$/i       => 'REFERENCES',
    qr/^Section .*/i        => 'CHAPTER_START',
    qr/^Table of Con.*/i    => 'TABLE_OF_CONTENTS',
    qr/^Title Page$/i       => 'TITLE'
};


sub _extract_page_tags {

    my $self = shift;
    my $xc   = $self->get_source_mets_xpc();

    my $pagedata       = {};
    my $pagenumber_map = {};
    my $pagetag_map    = {};

    $self->{in_body}       = 0;
    $self->{at_start}      = 1;
    $self->{had_backcover} = 0;

    # Extract info from the physical structmap
    foreach my $struct_div (
        $xc->findnodes(
            q(//mets:structMap[@TYPE='physical']//mets:div[mets:fptr]))
      )
    {
        my $pagetags = [];

        warn("Another div after back cover") if $self->{had_backcover};
        $self->_check_is_page($struct_div);

        my $orderlabel = $self->_extract_page_number( $struct_div, 'ORDERLABEL' );

        $self->_map_label_page_tag( $struct_div, $pagetags );

        $self->{at_start} = 0;

        foreach
          my $fptr ( $struct_div->getChildrenByTagNameNS( NS_METS, 'fptr' ) )
        {
            my $fileid = $fptr->getAttribute('FILEID');
	    (my $seqnum) = ($fileid =~ /(\d+)/);
	    die("Can't extract sequence number from file $fileid") unless $seqnum;

            if ( $fileid =~ /^IMG/i ) {
                $self->_set_pagenumber( $seqnum, $orderlabel, $pagenumber_map );
                $pagetag_map->{$seqnum} = $pagetags;
            }
        }
    }

    # Extract info from the logical structmap

    # collect and collate pagetags per leaf-level div
    my $pagetags = [];
    $self->{at_start}      = 1;
    $self->{in_body}       = 0;
    $self->{had_backcover} = 0;

    foreach my $struct_div (
        $xc->findnodes(q(//mets:structMap[@TYPE='logical']//mets:div)) )
    {
        my @fptrs = $struct_div->getChildrenByTagNameNS( NS_METS, 'fptr' );
        if (@fptrs) {

            # div representing actual page
            $self->_check_is_page($struct_div);

            my $orderlabel = $self->_extract_page_number( $struct_div, 'ORDERLABEL' );
            my $label      = $self->_extract_page_number( $struct_div, 'LABEL' );

            foreach my $fptr (
                $struct_div->getChildrenByTagNameNS( NS_METS, 'fptr' ) )
            {
                warn("Another div after back cover") if $self->{had_backcover};
		my $fileid = $fptr->getAttribute('FILEID');
		(my $seqnum) = ($fileid =~ /(\d+)/);
		die("Can't extract sequence number from file $fileid") unless $seqnum;

                if ( $fileid =~ /^IMG/i ) {
                    $self->_set_pagenumber( $seqnum, $orderlabel, $pagenumber_map )
                      if defined $orderlabel;
                    $self->_set_pagenumber( $seqnum, $label, $pagenumber_map )
                      if defined $label;

                    # update pagetags
                    if (@$pagetags) {
                        my $file_pagetags = $pagetag_map->{$seqnum};
                        $file_pagetags = [] if not defined $file_pagetags;
                        push( @$file_pagetags, @$pagetags );
                        $pagetag_map->{$seqnum} = $file_pagetags;
                        $pagetags = [];
                    }
                }

                $self->{at_start} = 0;
            }

        }
        else {

            # non-leaf div
            my $type = $struct_div->getAttribute('TYPE');
            if ( defined $type ) {
                my $type_tag = $type_map->{$type};
                push( @$pagetags, $self->_map_preface_chapter($type_tag) )
                  if defined $type_tag;
            }
            else {
                warn( "Missing type on div" . $struct_div->toString() );
            }

            $self->_map_label_page_tag( $struct_div, $pagetags );

        }
    }

    foreach my $seqnum ( uniq( sort( keys(%$pagenumber_map), keys(%$pagetag_map) ) ) ) {
        my $pagenum = $pagenumber_map->{$seqnum};
        my $rawtags = $pagetag_map->{$seqnum};
        my @tags    = uniq( sort(@$rawtags) );

        $pagedata->{$seqnum} = {
            orderlabel => $pagenum,
            label      => join( ' ', @tags )
        };

    }

    return $pagedata;

}

sub _map_preface_chapter {
    my $self = shift;
    my $tag = shift;

    # Enforce rule that start of front matter sections should
    # be tagged as CHAPTER_START if it uses the regular page
    # numbering, PREFACE otherwise
    if ( $tag eq '??_PREFACE' ) {
        if ($self->{in_body}) {
            $tag = 'CHAPTER_START';
        }
        else {
            $tag = 'PREFACE';
        }
    }
    elsif ( $tag eq '??_COVER' ) {

        # Try to figure out which cover this is..
        if ($self->{at_start}) {
            $tag = 'FRONT_COVER';
        }
        else {
            $self->{had_backcover} = 1;
            $tag           = 'BACK_COVER';
        }
    }
    return $tag;
}

sub _map_label_page_tag {
    my $self = shift;
    my $struct_div = shift;
    my $pagetags   = shift;

    if ( $struct_div->hasAttribute('LABEL') ) {
        my $label = $struct_div->getAttribute('LABEL');
        while ( my ( $tag_re, $tag ) = each %$label_map ) {
            if ( $label =~ $tag_re ) {

                $tag = $self->_map_preface_chapter($tag);

            }
            push( @$pagetags, $tag ) if $label =~ $tag_re;

        }
    }
}

sub _check_is_page {
    my $self = shift;
    my $struct_div = shift;
    if ( $struct_div->hasAttribute('TYPE') ) {
        my $type = $struct_div->getAttribute('TYPE');
        warn("Unexpected type $type") unless $type eq 'page';
    }
    else {
        warn('Missing TYPE attribute on div');
    }
}

sub _extract_page_number {
    my $self = shift;
    my $struct_div = shift;
    my $attribute  = shift;

    if ( $struct_div->hasAttribute($attribute) ) {
        my $pagenum = $struct_div->getAttribute($attribute);
        warn( "missing attribute $attribute on div " . $struct_div->toString() )
          if not defined $pagenum;
        warn("Unexpected page number $pagenum")
          unless $pagenum =~ /^\d+$/
              or $pagenum =~ /^[ivxlcdm]+$/;
        $self->{in_body} = 1 if $pagenum =~ /^\d+$/;
        return $pagenum;
    }
    else {
        return;
    }
}

sub _set_pagenumber {
    my $self = shift;
    my $filename       = shift;
    my $newnumber      = shift;
    my $pagenumber_map = shift;
    if ( defined $newnumber ) {
        warn("Inconsistent page numbering for $filename")
          if (  $pagenumber_map->{$filename}
            and $pagenumber_map->{$filename} ne $newnumber );

        $pagenumber_map->{$filename} = $newnumber;
    }
}
