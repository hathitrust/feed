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


1;

__END__
