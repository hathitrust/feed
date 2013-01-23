#!/usr/bin/perl
 
package HTFeed::PackageType::Audio::METS;
use HTFeed::METSFromSource;
# get the default behavior from HTFeed::METSFromSource
use base qw(HTFeed::METSFromSource);
use Log::Log4perl qw(get_logger);
 
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

    my $notes_txt = new METS::MetadataSection( 'techMD',
        id => $self->_get_subsec_id('techMD'));

    my @mdwraps = $xc->findnodes('//mets:mdRef[@LABEL="production notes"] | //mets:mdRef[@LABEL="Production notes"]');
    if(@mdwraps == 1) {
        $notes_txt->set_mdwrap($mdwraps[0]);
    } else {
        my $count = scalar(@mdwraps);
        $self->set_error("BadField",field=>"production notes",decription=>"Found $count production notes techMDs, expected 1");
#        $notes_txt->set_md_ref(
#            label => 'production notes',
#            loctype => 'OTHER',
#            otherloctype => 'SYSTEM',
#            mdtype => 'OTHER',
#            othermdtype => 'text',
#            xlink => { href => 'notes.txt'}
#        );

    }
    push(@{ $self->{amd_mdsecs} },$notes_txt);
}

sub _add_content_fgs {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $src_mets_xpc  = $volume->get_source_mets_xpc();
    my @filegrp_nodes = $src_mets_xpc->findnodes("//mets:fileGrp");
    foreach my $filegrp_node (@filegrp_nodes) {
        foreach my $file_node ( $src_mets_xpc->findnodes( "./mets:file", $filegrp_node ) ) {
            $file_node->removeAttribute('DMDID');
            $file_node->removeAttribute('ADMID');
        }
        my $filegrp_id = $self->_get_subsec_id("FG");

        $filegrp_node->setAttribute( "ID", $filegrp_id );
        $mets->add_filegroup($filegrp_node);
    }

	# add notes.txt if present
    my $files = $volume->get_all_directory_files();
    if(grep(/^notes\.txt/i, @$files)){
		my $filegroups = $volume->get_file_groups();
		$self->{filegroups} = {};
		while ( my ( $filegroup_name, $filegroup) = each(%$filegroups)){

			next unless($filegroup_name eq "notes");

			my $mets_filegroup = new METS::FileGroup(
				id => $self->_get_subsec_id("FG"),
				use => $filegroup->get_use(),
			);
			$mets_filegroup->add_files($filegroup->get_filenames(),
				prefix => $filegroup->get_prefix(),
				path => $volume->get_staging_directory()
			);

			$self->{filegroups}{$filegroup_name} = $mets_filegroup;
			$mets->add_filegroup($mets_filegroup);
		}
    }
}



1; 
