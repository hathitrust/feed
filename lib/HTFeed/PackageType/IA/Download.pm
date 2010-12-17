package HTFeed::PackageType::IA::Download;

use warnings;
use strict;
use base qw(HTFeed::Stage::Download);
use HTFeed::Config qw(get_config);
use File::Pairtree;
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
        my $url = $url . $filename;
        $self->download(url => $url, path => $pt_path, filename => $filename);
    }

    foreach my $item (@$non_core_package_items){
        my $filename = sprintf($item,$ia_id);
        my $url = $url . $filename;
        $self->download(url => $url, path => $pt_path, filename => $filename, not_found_ok => 1) or push(@noncore_missing,$filename);
    }

    # handle scandata..

    if(!$self->download(url => $url, path => $pt_path, filename => "${ia_id}_scandata.xml", not_found_ok => 1)) {
        $self->download(url => $url, path => $pt_path, filename => "scandata.zip", not_found_ok => 0) or return;
        unzip_file($self,"-d '$pt_path'","$pt_path/scandata.zip scandata.xml");
        if(!-e "$pt_path/${ia_id}_scandata.xml") {
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

    $self->{volume}->record_premis_event("package inspection",outcome => $outcome);

    $self->_set_done();
    return $self->succeeded();
}


1;

__END__
