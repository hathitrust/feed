#!/usr/bin/perl
 
package HTFeed::PackageType::Audio::METS;
use HTFeed::METSFromSource;
# get the default behavior from HTFeed::METSFromSource
use base qw(HTFeed::METSFromSource);
 
sub _add_dmdsecs {
    return;
}

sub _add_techmds {

    my $self = shift;
    my $volume = $self->{volume};

	# Only add techmd if there is a notes.txt present in the package
	my $files = $volume->get_all_directory_files();

	unless(grep(/^notes\.txt/i, @$files)){
		#no notes.txt; skip
		return;
	}

    my $xc = $volume->get_source_mets_xpc();
    $self->SUPER::_add_techmds();

    my $reading_order = new METS::MetadataSection( 'techMD',
        id => $self->_get_subsec_id('techMD'));

    my @mdwraps = $xc->findnodes('//METS:mdRef[@LABEL="production notes"]');
    if(@mdwraps != 1) {
        my $count = scalar(@mdwraps);
        $self->set_error("BadField",field=>"production notes",decription=>"Found $count production notes techMDs, expected 1");
    }
    $reading_order->set_mdwrap($mdwraps[0]);
    push(@{ $self->{amd_mdsecs} },$reading_order);
}


1; 
