package HTFeed::PackageType::IA::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Config qw(get_config);
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path remove_tree);
use Carp qw(croak);
use File::Path qw(remove_tree);


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

sub reset {
    my $self = shift;
    delete $self->{meta_xpc};
    $self->SUPER::reset;
}

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
    my $sth = $dbh->prepare("select ia_id from feed_ia_arkid where arkid = ?");
    $sth->execute($arkid);

    my $results = $sth->fetchrow_arrayref();

    #TODO make this work if db result is null
    $ia_id = $results->[0];

    croak("Missing IA ID for $arkid") if not defined $ia_id or $ia_id eq '';
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
    my $pt_path = "$path/ia/$ia_id";
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

    # use source METS if we have it, otherwise try downloaded scandata.xml
    my $mets = $self->get_source_mets_file();
    if(defined $mets) {
        my $xpc = $self->get_source_mets_xpc();
        if(defined $xpc) {
            $xpc->registerNs('scribe','http://archive.org/scribe/xml');
            return $xpc;
        }
    }
    if(not defined $self->{scandata_xpc}) {
        my $path = $self->get_download_directory();
        my $ia_id = $self->get_ia_id();

        my $xpc = $self->_parse_xpc("$path/${ia_id}_scandata.xml");
        $xpc->registerNs('scribe','http://archive.org/scribe/xml');
        $self->{scandata_xpc} = $xpc;

    }
    return $self->{scandata_xpc};
}

sub get_meta_xpc {
    my $self = shift;
    # use source METS if we have it, otherwise try downloaded meta.xml
    my $mets = $self->get_source_mets_file();
    if(defined $mets) {
        my $xpc = $self->get_source_mets_xpc();
        if(defined $xpc) {
            return $xpc;
        }
    }
    if(not defined $self->{meta_xpc}) {
        my $path = $self->get_download_directory();
        my $ia_id = $self->get_ia_id();

        my $xpc = $self->_parse_xpc("$path/${ia_id}_meta.xml");
        $self->{meta_xpc} = $xpc;

    }
    return $self->{meta_xpc};
}

sub get_download_location {
    my $self = shift;
    # IA has multiple files in SIP
    return $self->get_download_directory();
}

# resolution override as defined in feed_ia_arkid
# for locally-digitized material missing resolution

sub get_db_resolution {
  my $self = shift;
  my $arkid = $self->get_objid();

  my $dbh = get_dbh();
  my $sth = $dbh->prepare("select resolution from feed_ia_arkid where arkid = ?");
  $sth->execute($arkid);

  my $results = $sth->fetchrow_arrayref();

  return $results->[0];
}

sub clean_sip_success {
  my $self = shift;
  return $self->clean_download();
}

sub clean_sip_failure {
  my $self = shift;
  return $self->clean_download();
}

# unlink SIP
sub clean_download {
    my $self = shift;
    my $dir = $self->get_download_location();
    if(defined $dir) {
        return remove_tree($dir);
    }
}

# This method is not reliable.
#
# # determine either from source mets or from meta.xml depending on where in the process we are
# sub is_ia_local_upload {
#   my $self = shift;
#   my $xpc = undef; 
#   if($self->get_source_mets_file()) {
#     $xpc = $self->get_source_mets_xpc();
#   } else {
#     $xpc = $self->get_meta_xpc();
#   }
# 
#   my $uploader = $xpc->findvalue("//uploader");
#   my $operator = $xpc->findvalue("//operator");
# 
#   if( ($uploader and $uploader !~ /archive\.org$/)
#       or ($operator and $operator !~ /archive\.org$/)) {
#     return 1;
#   } else {
#     return 0;
#   }
# }

# use contributor from meta.yml if not ia-digitized
sub tiff_artist {
  my $self = shift;
  my $xpc = $self->get_meta_xpc();

  my $uploader = $xpc->findvalue("//uploader");
  my $operator = $xpc->findvalue("//operator");

  if( ($uploader and $uploader !~ /archive\.org$/)
      or ($operator and $operator !~ /archive\.org$/)) {
    return $xpc->findvalue("//contributor");
  } else {
    return "Internet Archive";
  }
}

# This method is not reliable, so just use the base method which trusts the value coming from
# Zephir.

# sub apparent_digitizer {
#   my $self = shift;
#   if($self->is_ia_local_upload()) {
#     my $providers = ($self->get_sources)[0];
#     $providers =~ s/\*//g;
#     my @providers = split(';',$providers);
#     return shift @providers;
#   } else {
#     return 'archive'
#   }
# }

1;

__END__
