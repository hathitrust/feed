#!/usr/bin/perl

package HTFeed::METS;
use METS;
use PREMIS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas);

sub new {
    my $class  = shift;
    my $volume = shift;

    return bless { volume => $volume }, $class;

}

sub run_stage {
    my $self = shift;
    my $mets = new METS( objid => "$namespace.$objid" );
    $self->{'mets'} = $mets;

    eval {
        $self->_add_schemas();
        $self->_add_header();
        $self->_add_dmdsecs();
        $self->_add_techmds();
        $self->_add_premis();
        $self->_add_filesecs();
        $self->_add_structmap();
        $self->_save_mets();
    };

}

sub _add_schemas {
    my $self = shift;
    my $mets = $self->{mets};

    $mets->add_schema( "PREMIS", NS_PREMIS, SCHEMA_PREMIS );
    $mets->add_schema( "MARC",   NS_MARC,   SCHEMA_MARC );

}

sub _add_header {
    my $header = new METS::Header(
        createdate   => _get_createdate(),
        recordstatus => 'NEW'
    );
    $header->add_agent(
        role => 'CREATOR',
        type => 'ORGANIZATION',
        name => 'DLPS'
    );

    $mets->set_header($header);

    # Google: altRecordID handling - reject if there is an altRecordID in the
    # source METS. This should only happen if the volume is a duplicate, which
    # should be detected by looking for condition 31 set and source library
    # bibkey not null, but it doesn't hurt to check.

    # IA: add an altRecordID with the IA identifier
}

sub _add_dmdsecs {
    my $self   = shift;
    my $volume = $self->{volume};
    my $mets   = $self->{mets};

    my $dmdsec =
      new METS::MetadataSection( 'dmdSec',
        'id' => $self->_get_subsec_id("DMD") );
    $dmdsec->set_md_ref(
        mdtype       => 'MARC',
        loctype      => 'OTHER',
        otherloctype => 'Item ID stored as second call number in item record',
        xptr => $volume->get_identifier()
    );
    $mets->add_dmd_sec($dmdsec);

    $dmdsec =
      new METS::MetadataSection( 'dmdSec',
        'id' => $self->_get_subsec_id("DMD") );
    $dmdsec->set_data(
        $volume->get_marc_xml(),
        mdtype => 'MARC',
        label  => 'Physical volume MARC record'
    );

    # MIU: add TEIHDR; do not add second call number??
}

sub _add_techmds {

    # Google: notes.txt and pagedata.txt should no longer be present

    # MIU: loadcd.log, checksum, pageview.dat, target files?

    # UMP: PDF?

}

# extract existing PREMIS events from object currently in repos
sub _extract_old_premis {
    my $self = shift;

    my $mets_in_repos = $book->mets_in_repos();
    if(defined $mets_in_repos) {
        # validate METS in repository
        # my ($mets_in_rep_valid,$val_results) = validate_xml($self->{'config'},$mets_in_repository);
        if($mets_in_rep_valid) {
            # TODO extract old premis events (old _store_premis_events)
        }
        else {
            # log warning that METS in repository exists but isn't valid
        }
    }
}

sub _add_premis {
    my $self = shift;
    my $volume = $self->{volume};

    $self->_extract_old_premis();

    # create PREMIS object
    my $premis = new PREMIS;
    my $premis_object = new PREMIS::Object('identifier',$volume->get_identifier());
    $premis_object->set_preservation_level("1");
    $premis_object->add_significant_property('file count',$volume->get_file_count());
    $premis_object->add_significant_property('page count',$volume->get_page_count());

    # Events:
    # capture
    # message digest calculation
    # compression (all but ia)
    # blank OCR creation (ump only)
    # decryption (mdp only)
    # fixity check
    # preingest transformation
    # validation
    # message digest calculation  (again??)
    # page feature mapping
    # ingestion

}


sub _get_subsec_id {
    my $self        = shift;
    my $subsec_type = shift;
    $self->{counts} = {} if not exists $self->{counts};
    $self->{counts}{$subsec_type} = 0
      if not exists $self->{counts}{$subsec_type};
    return "$subsec_type" . ++$self->{counts}{$subsec_type};
}

sub _add_filesecs {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    # first add zip
    my $zip_filegroup = new METS::FileGroup(
        id  => $self->_get_subsec_id("FG"),
        use => 'zip archive'
    );
    $zip_filegroup->add_file( $volume->get_zip(), prefix => 'ZIP' );
    $mets->add_filegroup($zip_filegroup);

    # then add the actual content files
    my $filegroups = $volume->get_file_groups();
    $self->{filegroups} = {};
    while ( my ( $filegroup_name, $filegroup ) = each(%$filegroups) ) {
        my $mets_filegrp = new METS::FileGroup(
            id  => $self->_get_subsec_id("FG"),
            use => $filegroup->get_use()
        );
        $mets_filegrp->add_files( $filegroup->get_filenames(),
            prefix => $filegroup->get_prefix() );

        $self->{filegroups}{$filegroup_name} = $mets_filegrp;
        $mets->add_filegroup($mets_filegroup);
    }

    # MIU: Extra stuff for MIU: archival XML, objid XML?

}

sub _add_structmap {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $structmap = new METS::StructMap( id => 'SM1', type => 'physical' );
    my $voldiv = new METS::StructMap::Div( type => 'volume' );
    $struct_map->add_div($voldiv);
    my $order               = 1;
    my $file_groups_by_page = $volume->get_file_groups_by_page();
    foreach my $pagefiles (@$file_groups_by_page) {
        my $pagediv_ids = [];
        my $pagedata;
        while ( my ( $filegroup_name, $files ) = each(%$pagefiles) ) {
            foreach my $file (@$files) {
                my $fileid = $self->{filegroups}{$filegroup_name}{$file};
                croak("Can't find file ID for $file in $filegroup_name")
                  unless defined $fileid;

                # try to find page number & page tags for this page
                if ( not defined $pagedata ) {
                    $pagedata = $volume->get_pagedata($fileid);
                }

                push( @$pagediv_ids, $fileid );
            }
        }
        $voldiv->add_file_div(
            $pagediv_ids,
            order => $order++,
            type  => 'page',
            @$pagedata
        );
    }

}

sub _save_mets {
    my $self   = shift;
    my $mets   = $self->{mets};
    my $volume = $self->{volume};

    my $mets_path = $self->{volume}->get_mets_path();

    open( $metsxml, ">", "$mets_path" )
      or die("Can't open IA METS xml $mets_path for writing: $!");
    print $metsxml $mets->to_node()->toString(1);
    close($metsxml);
}

sub validate {
    my $self      = shift;
    my $mets_path = $self->{volume}->get_mets_path();

    croak("METS file $$self{'filename'} does not exist. Cannot validate.")
      unless -e $mets_path;

    my ( $mets_valid, $val_results ) =
      validate_xml( $self->{'config'}, $$self{'filename'} );
    if ( !$mets_valid ) {
        $self->set_error(
            "METS file invalid",
            file   => $mets_path,
            detail => $val_results
        );

        # TODO: set failure creating METS file
        return;
    }

}

sub validate_xml {
    # TODO: Use new global config mechanism
    my $config = new GROOVE::Config;
    my $xerces = $config->get('xerces_command');

    my $filename       = shift;
    my $validation_cmd = "$xerces -f -p $filename 2>&1";
    my $val_results    = `$validation_cmd`;
    if ( $val_results =~ /Error/ || $? ) {
        wantarray ? return ( 0, $val_results ) : return (0);
    }
    else {
        wantarray ? return ( 1, undef ) : return (0);
    }

}

=item _get_createdate $ss1970

Given ss1970, use Time::localtime to generate a date with format: yyyy-mm-ddT13:27:00

=cut

sub _get_createdate {
    my $self = shift;
    my $ss1970 = shift;

    my $localtime_obj = defined($ss1970) ? localtime($ss1970) : localtime();

    my $ts = sprintf("%d-%02d-%02dT%02d:%02d:%02d",
        (1900 + $localtime_obj->year()),
        (1 + $localtime_obj->mon()),
        $localtime_obj->mday(),
        $localtime_obj->hour(),
        $localtime_obj->min(),
        $localtime_obj->sec());

    return $ts;
}

