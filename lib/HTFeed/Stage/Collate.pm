package HTFeed::Stage::Collate;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use File::Path qw(make_path);
use File::Copy;
use File::Pairtree;

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $objid = $volume->get_objid();
    my $pairtree_objid = s2ppchars($objid);
    my $pairtree_path = sprintf('%s/%s%s',get_config('repository_path'),id2ppath($pairtree_objid),$pairtree_objid);
    my $staging_dir = get_config('staging'=>'memory');

    ##TODO: what do we do if this is a re-ingest?
    if (-f $pairtree_path){
        
    }
    else{
        make_path($pairtree_path);
    }

    ## TODO check failure
    # move mets and zip
    copy ( sprintf("%s/%s.mets.xml",$staging_dir,$objid),
            sprintf("%s/%s.mets.xml",$pairtree_path,$pairtree_objid) );
    copy ( sprintf("%s/%s.zip",$staging_dir,$objid),
            sprintf("%s/%s.zip",$pairtree_path,$pairtree_objid) );

    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
