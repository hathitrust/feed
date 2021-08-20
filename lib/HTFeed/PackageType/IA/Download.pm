package HTFeed::PackageType::IA::Download::LinkParser;
use base qw(HTML::Parser);
use strict;
# parse links

sub start { 
    my ($self, $tagname, $attr, $attrseq, $origtext) = @_;
    if ($tagname eq 'a') {
        push(@{$self->{links}}, $attr->{href});
    }
}

sub links {
    my $self = shift;
    return $self->{links};
}

package HTFeed::PackageType::IA::Download;
use Encode qw(decode);

use warnings;
use strict;
use base qw(HTFeed::Stage::Download);
use LWP;
use HTFeed::Config qw(get_config);
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);
use HTFeed::Stage::Unpack qw(unzip_file);
use Log::Log4perl qw(get_logger);

my $download_base = "http://www.archive.org/download/";

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $arkid = $volume->get_objid();
    my $ia_id = $volume->get_ia_id();

    my $core_package_items = $volume->get_nspkg()->get('core_package_items');
    my $non_core_package_items = $volume->get_nspkg()->get('non_core_package_items');

    my $url = "${download_base}${ia_id}/";
    my $pt_path = $volume->get_download_directory();
    $self->{pt_path} = $pt_path;


    my @noncore_missing = ();

    foreach my $suffix (@$core_package_items){
        $self->download(suffix => $suffix);
    }

    foreach my $suffix (@$non_core_package_items){
        $self->download(suffix => $suffix, not_found_ok => 1) or push(@noncore_missing,$suffix);
    }

#    # if MARC-XML is not on IA we'll just get it from Zephir
#    $self->download(suffix => "marc.xml", not_found_ok => 1);

    # handle jp2 - try tar if zip is not found
    if(!$self->download(suffix => "jp2.zip", not_found_ok => 1)) {
        $self->download(suffix => "jp2.tar");
    }

    # handle scandata..

    if(!$self->download(suffix => "scandata.xml", not_found_ok => 1)) {
        $self->download(suffix => "scandata.zip", filename => "scandata.zip") or return;
        unzip_file($self,"$pt_path/scandata.zip",$pt_path,"scandata.xml");
        if(!-e "$pt_path/scandata.xml") {
            $self->set_error("MissingFile",file => 'scandata.zip/scandata.xml');
            return;
        }
        rename("$pt_path/scandata.xml","$pt_path/${ia_id}_scandata.xml") or do {
            $self->set_error('OperationFailed',operation=>'rename',file => "$pt_path/scandata.xml");
            return;
        }

    }

    my $outcome;
    if(@noncore_missing) {
        $outcome = PREMIS::Outcome->new('warning');
        $outcome->add_file_list_detail( "files missing",
                        "missing", \@noncore_missing );
    } else {
        $outcome = PREMIS::Outcome->new('pass');
    }

    $self->{volume}->record_premis_event("package_inspection",outcome => $outcome);

    $self->_set_done();
    return $self->succeeded();
}

sub download {
    my $self = shift;
    my %args = @_;
    my $not_found_ok = $args{not_found_ok};
    my $ia_id = $self->{volume}->get_ia_id();
    my $suffix = $args{suffix};

    $not_found_ok = 0 if not defined $not_found_ok;

    my $filename = $args{filename};
    $filename = "${ia_id}_$suffix" if not defined $filename;

    # check if it was already downloaded
    return 1 if -e "$self->{pt_path}/$filename";


    foreach my $link (@{$self->get_links()}) {
      next if not defined $link;
        if ($link =~ /$suffix$/ and $link !~ /_bw_$suffix/) {

            return $self->SUPER::download(path => $self->{pt_path}, 
                filename => $filename, 
                url => "$download_base$ia_id/$link", 
                not_found_ok => $not_found_ok);
        }
    }

    if ($not_found_ok) {
      get_logger()->debug("Can't find $filename linked from $download_base$ia_id");
    } else {
      $self->set_error('MissingFile',file => $filename,detail => "Can't find file linked from $download_base$ia_id");
    }

}

sub get_links {
    my $self = shift;

    if(not defined $self->{links}) {
        my $ua = LWP::UserAgent->new;
        my $ia_id = $self->{volume}->get_ia_id();
        my $url = "http://www.archive.org/download/$ia_id/";

        my $req = HTTP::Request->new('GET', $url);
        my $res = $ua->request($req);

        my $parser = HTFeed::PackageType::IA::Download::LinkParser->new;
        $parser->parse(decode('UTF-8',$res->content));

        $self->{links} = $parser->links;
    }

    return $self->{links};

}

1;

__END__
