package HTFeed::PackageType::IA::Download;

use warnings;
use strict;
use base qw(HTFeed::Stage::Download);
use HTFeed::Config qw(get_config);
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);
use HTFeed::Stage::Unpack qw(unzip_file);

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $arkid = $volume->get_objid();
    my $ia_id = $volume->get_ia_id();

    my $core_package_items = $volume->get_nspkg()->get('core_package_items');
    my $non_core_package_items = $volume->get_nspkg()->get('non_core_package_items');

    my $url = "http://www.archive.org/download/$ia_id/";
    my $pt_path = $volume->get_download_directory();


    my @noncore_missing = ();

    foreach my $item (@$core_package_items){
        my $filename = sprintf($item,$ia_id);
        $self->download(url => $url . $filename, path => $pt_path, filename => $filename);
    }

    foreach my $item (@$non_core_package_items){
        my $filename = sprintf($item,$ia_id);
        $self->download(url => $url . $filename, path => $pt_path, filename => $filename, not_found_ok => 1) or push(@noncore_missing,$filename);
    }

    # if MARC-XML is not on IA try to get it locally
    if(!$self->download(url=> $url . "${ia_id}_marc.xml", path => $pt_path, filename => "${ia_id}_marc.xml", not_found_ok => 1)) {
        my $possible_path = get_config('sip_root') . "/marc/${ia_id}_marc.xml";
        if(-e get_config('sip_root') . "/marc/${ia_id}_marc.xml") {
            system("cp","$possible_path","$pt_path/${ia_id}_marc.xml");
        } else {
            $self->set_error("MissingFile",file=>"${ia_id}_marc.xml");
        }
    }

    # handle jp2 - try tar if zip is not found
    if(!$self->download(url => $url . "${ia_id}_jp2.zip", path => $pt_path, filename => "${ia_id}_jp2.zip", not_found_ok => 1)) {
        $self->download(url => $url . "${ia_id}_jp2.tar", path => $pt_path, filename => "${ia_id}_jp2.tar", not_found_ok => 0);
    }

    # handle scandata..

    if(!$self->download(url => $url . "${ia_id}_scandata.xml", path => $pt_path, filename => "${ia_id}_scandata.xml", not_found_ok => 1)) {
        $self->download(url => $url . "scandata.zip", path => $pt_path, filename => "scandata.zip", not_found_ok => 0) or return;
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
    my $orig_url = $args{url};

    # replace the pattern '$search' with the pattern '$replace', but
    # only in the filename part of the URL
    sub filename_replace {
        use re 'eval';
        # allow interpolation in $replace
        my ($string,$search,$replace) = @_;
        $replace = '"$+{begin}' . $replace . '$+{end}"';
        $string =~ s#(?<begin>/[^/]+)$search(?<end>[^/]+)$#$replace#ee;
        return $string;
    }
    
    my @subs = ( 
        sub { my $x = shift; return $x; }, # noop
        # Clark Art: e.g. MAB.31962000741953Images -> MAB.31962000741953__Images
        sub { my $x = shift; $x = filename_replace($x,'Images','_Images'); return $x; },
        sub { my $x = shift; $x = filename_replace($x,'Images','__Images'); return $x; },
        # Emory: e.g. 02783702.9242.emory.edu -> 02783702_9242
        sub { my $x = shift; $x = filename_replace($x,'.emory.edu',''); $x = filename_replace($x,qr((?<id1>\d+)\.(?<id2>\d+)),'$+{id1}_$+{id2}'); return $x; }
    );

    foreach my $sub (@subs) {
        my $new_url = &$sub($orig_url);
        if( $self->SUPER::download(filename => $args{filename}, path => $args{path}, url => $new_url,  not_found_ok => 1)) {
            return 1;
        }
    }

    if(!$not_found_ok) {
        $self->set_error("OperationFailed",file => $args{filename},operation=>'download',detail => "No variants for $args{filename} found");
    }
    return 0;

}


1;

__END__
