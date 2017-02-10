#!/usr/bin/perl
 
package HTFeed::PackageType::Audio::METS;
use HTFeed::METSFromSource;
# get the default behavior from HTFeed::METSFromSource
use base qw(HTFeed::METSFromSource);
use Log::Log4perl qw(get_logger);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        @_,
    );
    $self->{profile} = "http://www.hathitrust.org/documents/hathitrust-audio-mets-profile1.0.xml";
    $self->{required_events} = ["fixity check","validation","ingestion"];

    return $self;
}
 
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
        $self->set_error("BadField",field=>"production notes",description=>"Found $count production notes techMDs, expected 1");
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

sub _extract_old_premis {
    my $self = shift;
    my $volume = $self->{volume};
    my $events = $self->SUPER::_extract_old_premis();

    # if there was no message digest calculation event, add one
    my $mets_in_repos = $volume->get_repository_mets_path();
    my $xc = $volume->get_repository_mets_xpc();

    if(defined $xc) {
        my @message_calc = $xc->findnodes("//premis:event/premis:eventType[text()='message digest calculation']");
        if(!@message_calc) {
            # missing message digest calculation: try to add it
            my $last_ingest = undef;

            foreach my $ingest_date_node ($xc->findnodes("//premis:event[premis:eventType[text()='ingestion']]/premis:eventDateTime")) {
                my $ingest_date = $ingest_date_node->textContent();
                if(not defined $last_ingest or $ingest_date gt $last_ingest) {
                    $last_ingest = $ingest_date
                }
            }
            $self->set_error("MissingField",field=>"ingest date",file=>$mets_in_repos,detail=>"Can't get last ingest date from source METS") if not defined $last_ingest;

            $last_ingest = $self->convert_tz($last_ingest,"America/Detroit") 
                if defined $last_ingest and $last_ingest and $last_ingest !~ /Z$/;
            my $eventid = $volume->make_premis_uuid('message digest calculation',$last_ingest);
            my $nspkg           = $volume->get_nspkg();
            # add premis event
            my $eventconfig =   $nspkg->get_event_configuration('page_md5_create');
            $eventconfig->{eventid} = $eventid;
            $eventconfig->{date} = $last_ingest;
            $self->add_premis_event($eventconfig);

        }
    }

    return $events;
}



1; 
