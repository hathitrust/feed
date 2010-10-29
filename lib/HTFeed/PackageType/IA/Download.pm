package HTFeed::PackageType::IA::Download;

use warnings;
use strict;
use base qw(HTFeed::Stage::Download);
use HTFeed::Config qw(get_config);

sub run{
    my $self = shift;
    
    my $volume = $self->{volume};
    my $arkid = $volume->get_objid();
    my $ia_id = $volume->get_ia_id();
    
    my $core_package_items = $volume->get_nspkg()->get('core_package_items');
    my $non_core_package_items = $volume->get_nspkg()->get('non_core_package_items');
    
    my $url = "http://www.archive.org/download/$ia_id/";
    my $path = get_config('staging'=>'disk');

    foreach my $item (@$core_package_items){
        my $filename = sprintf($item,$ia_id);
        my $url = $url . $filename;
        $self->download(url => $url, path => $path, filename => $filename);
    }
    
    foreach my $item (@$non_core_package_items){
        my $filename = sprintf($item,$ia_id);
        my $url = $url . $filename;
        $self->download(url => $url, path => $path, filename => $filename, not_found_ok => 1);
    }
    
    $self->_set_done();
    return $self->succeeded();
}


1;

__END__
