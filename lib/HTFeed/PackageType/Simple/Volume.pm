package HTFeed::PackageType::Simple::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::Config;
use Log::Log4perl qw(get_logger);
use YAML::Any qw(LoadFile);
use Carp qw(croak);

# front for YAML file


my @allowed_pagetags = qw(BACK_COVER BLANK CHAPTER_PAGE CHAPTER_START COPYRIGHT
FIRST_CONTENT_CHAPTER_START FOLDOUT FRONT_COVER IMAGE_ON_PAGE INDEX
MISSING MULTIWORK_BOUNDARY PREFACE REFERENCES TABLE_OF_CONTENTS TITLE TITLE_PARTS);

# get yaml meta.xml

sub get_meta {
    my $self = shift;
    my $key = shift;


    if(not defined $self->{meta_yml}) {
        my $preingest = $self->get_preingest_directory();

        unless ( -e "$preingest/meta.yml" ) {
          $self->set_error("MissingFile", file => "meta.yml");
        }

        my $yaml;
        eval { $yaml = LoadFile("$preingest/meta.yml"); };

        if($@ and $@ =~ /YAML::XS::Load Error/) {
          $self->set_error("BadFile",detail => $@,file=>"meta.yml");
        } elsif($@) {
          die $@;
        }

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
            my $seq = $1;

            # validate pagetags -- warning instead of error if 'ignore_unknown_pagetags' is set
            if($v->{label}) {
              my @pagetags = split(/,\s*/,$v->{label});
              my @ok_pagetags = ();
              foreach my $tag (@pagetags) {
                if(not grep { $_ eq $tag } @allowed_pagetags) {
                  my @error_args = ("BadValue", namespace => $self->{namespace}, id=>$self->{id},
                    actual=>$v->{label},field=>"pagedata label");
                  if($self->get_nspkg()->get('ignore_unknown_pagetags')) {
                    get_logger()->warn(@error_args,detail=>"Ignoring unknown pagetag")
                  } else {
                    $self->set_error(@error_args,detail=>"Unknown pagetag")
                  }
                } else {
                  push(@ok_pagetags,$tag);
                }
              }
              if(@ok_pagetags) {
                $v->{label} = join(', ',@ok_pagetags);
              } else {
                delete $v->{label};
              }
            }

            $pagedata->{$seq} = $v;
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

sub clean_sip_success {
  my $self = shift;

  $self->SUPER::clean_sip_success();
  my $rclone = HTFeed::Rclone->new;
  $rclone->delete($self->dropbox_url());
}

sub dropbox_url {
  my $self = shift;

  my $download_base = 'dropbox:';
  my $nspkg = $self->get_nspkg();
  my $dropbox_folder = $nspkg->get('dropbox_folder');
  if (not defined $dropbox_folder) {
    croak('Dropbox folder not configured');
  }
  my $filename = $self->get_SIP_filename();
  return "$download_base$dropbox_folder/$filename";
}

1;

__END__
