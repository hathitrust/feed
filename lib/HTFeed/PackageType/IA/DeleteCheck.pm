
package HTFeed::PackageType::IA::DeleteCheck;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

#
# Check for missing image files and remove
# pageType=Delete/addToAccessFormats=false files #
#
# As far as an actual missing file, we don't count it as actually missing if
# it is a pageType=Delete/addToAccessFormats=false page.
#

sub run {
    my $self = shift;
    my $volume = $self->{volume};
    my $ia_id = $volume->get_ia_id();

    my $download_directory = $volume->get_download_directory();
    my $preingest_directory = $volume->get_preingest_directory();
    my %expected_pages;

    if(! -e "$download_directory/${ia_id}_scandata.xml") {
        $self->set_error("MissingFile",file => "${ia_id}_scandata.xml");
        return;
    }
    my $xc = $volume->get_scandata_xpc();

    foreach my $page_node ( $xc->findnodes('//scribe:pageData/scribe:page | //pageData/page') ) { 
        my $leafNum = $page_node->getAttribute("leafNum");
        if(not defined $leafNum or $leafNum eq '') {
            $logger->warn("Found page node with no leafNum");
            next;
        }
        my $pageType           = $xc->findvalue('./scribe:pageType | ./pageType',$page_node); 
        my $addToAccessFormats = $xc->findvalue('./scribe:addToAccessFormats | ./addToAccessFormats',$page_node); 

        my $filename = sprintf( "${ia_id}_%04d.jp2", $leafNum );

        my $missing_ok =
          ( $pageType eq 'Delete' or $addToAccessFormats eq 'false' );

        if ( -e "$preingest_directory/$filename" ) {
            if ($missing_ok) {
                unlink "$preingest_directory/$filename" if ($missing_ok);
                $logger->trace("$filename - pageType=$pageType deleted");
            }
        }
        elsif ($missing_ok) {
            $logger->trace("$filename - pageType=$pageType already removed");
        }
        else {
            # page missing unexpectedly
            $self->set_error("FileMissing",file => $filename,detail => "Missing page $leafNum, pageType=$pageType");
        }
    }

    $self->_set_done();

}

sub stage_info{
    return {success_state => 'delete_checked', failure_state => 'punted'};
}
