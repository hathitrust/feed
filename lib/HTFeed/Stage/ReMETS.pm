#!/usr/bin/perl

package HTFeed::Stage::ReMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use List::MoreUtils qw(pairwise);
use HTFeed::XMLNamespaces qw(:namespaces);
use base qw(HTFeed::Stage);

# Rebuilds the METS for the package from what's in the repository.


sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        @_,

        #		files			=> [],
        #		dir			=> undef,
        #		mets_name		=> undef,
        #		mets_xml		=> undef,
    );

    $self->{orig_stage} = # extract original METS class from packagetype
    return $self;
}

sub run {
    my $self = shift;
    my $volume = $self->{volume};

    # reset md5 checksum source to repo METS file??

    # add uplift METS events; mess with PREMIS events we will include.

    my $nspkg = $volume->get_nspkg();
    my $pkg_class = ref($nspkg);
    no strict 'refs';
    my $pkg_config = ${"${pkg_class}::config"};
    $pkg_config->{premis_events} = [
        'premis_migration',
        'mets_update'
    ];

    my $old_xpc = $volume->get_repository_mets_xpc();
    $self->{old_xpc} = $old_xpc;

    $volume->record_premis_event('mets_update');
    # run original METS stage
    my $mets_class = $volume->next_stage('packed');
    my $mets_stage =  eval "$mets_class->new(volume => \$volume, is_uplift => 1)";
    if(not defined $volume->get_source_mets_file() or ! -e $volume->get_source_mets_file()) {
       $mets_stage->{pagedata} = sub { $self->get_page_data_repository_mets(@_); };
    }
    $mets_stage->run();

    # compare new METS to old mets. must have:

    my $new_mets_file = $mets_stage->{outfile};
    $self->{new_mets_file} = $new_mets_file;
    my $new_xpc = $volume->_parse_xpc($new_mets_file);

    # make sure file count, page count, objid are the same
    my @queries = ("//premis:significantProperties[premis:significantPropertiesType='file count']/premis:significantPropertiesValue",
        "//premis:significantProperties[premis:significantPropertiesType='page count']/premis:significantPropertiesValue",
        '//mets:mets/@OBJID');
    foreach my $query (@queries) {
        my $old_val = $old_xpc->findvalue($query);
        # some old METS don't have the file count /page count
        next if not defined $old_val or $old_val eq '';
        my $new_val = $new_xpc->findvalue($query);
        $self->assert_equal($old_val,$new_val,$query);

    }

    # for each premis2 event type in old METS //premis:eventType/text()
      # count of events in new PREMIS much match count in old PREMIS //premis:eventType='$event_type'
    # is this an event we're migrating?
    my $migrate_events = $nspkg->get('migrate_events');
    foreach my $event_type_node ($old_xpc->findnodes("//premis:eventType")) {
        my $old_event_type = $event_type_node->textContent();
        my @new_event_types = ($old_event_type);

        if(my $new_event_tags = $migrate_events->{$old_event_type}) {
            @new_event_types = map { $nspkg->get_event_configuration($_)->{type} } @$new_event_tags;
        }

        foreach my $new_event_type (@new_event_types) {
            my $old_event_count = $old_xpc->findvalue("count(//premis:eventType[text()='$old_event_type'])");
            my $new_event_count = $new_xpc->findvalue("count(//premis:eventType[text()='$new_event_type'])");
            $self->assert_equal($old_event_count,$new_event_count,"count $old_event_type = $new_event_type)");
        }
    }

    # for each premis2 event type in new METS, verify a few things..
    foreach my $event_node ($new_xpc->findnodes("//premis:event")) {
        $self->assert_equal("UUID",$new_xpc->findvalue(".//premis:eventIdentifierType",$event_node),"eventIdentifierType");

        my $identifier = $new_xpc->findvalue(".//premis:eventIdentifierValue",$event_node);
        if(not defined $identifier or $identifier !~ /^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/) {
            $self->set_error("BadValue",field=>"eventIdentifierValue",file=>$new_mets_file,value=>$identifier);
        }
    }

    # for each //mets:file
    #   the //mets:file with that ID in the new METS must have the same attributes except CREATED
    #     the mets:FLocat/xlink:href must match as well
    foreach my $old_file ($old_xpc->findnodes("//mets:file")) {
        my $file_name = $old_xpc->findvalue('./mets:FLocat/@xlink:href',$old_file);
        my $new_file = ($new_xpc->findnodes("//mets:file[mets:FLocat/\@xlink:href='$file_name']"))[0];

        if(not defined $new_file) {
            $self->set_error("BadFile",file=>$file_name,detail=>"Missing reference to file in uplifted METS");
        }

        foreach my $attribute ($old_file->attributes(), $new_file->attributes()) {
            my $attr_name = $attribute->nodeName();
            next if lc($attr_name) eq 'created' or lc($attr_name) eq 'id';
            my $old_attr = $old_file->getAttribute($attr_name);
            my $new_attr = $new_file->getAttribute($attr_name);

            # ignore if file is XML and old mime type is HTML
            next if($file_name =~ /\.xml$/ and lc($attr_name) eq 'mimetype' and $new_attr = 'text/xml');
            next if($file_name =~ /\.pdf$/ and lc($attr_name) eq 'mimetype' and $new_attr = 'application/pdf');

            $self->assert_equal($old_attr,$new_attr,"$file_name $attr_name");
        }
    }

    # for each //mets:div
    #   the corresponding //mets:div must have the same attributes
    #   and the set of fptrs must point to the same files
    #   (although the IDs need not be the same)
    foreach my $old_div ($old_xpc->findnodes('//mets:div[@TYPE="page"]')) {
        my $order = $old_div->getAttribute('ORDER');
        my @new_divs = $new_xpc->findnodes("//mets:div[\@TYPE='page'][\@ORDER='$order']");
        $self->set_error("BadField",field=>"//mets:div[\@ORDER='$order']",file=>$new_mets_file) if scalar(@new_divs) != 1;
        my $new_div = shift @new_divs;

        my @old_fptrs;
        my @new_fptrs;
        foreach my $fileid ($old_xpc->findnodes("./mets:fptr/\@FILEID",$old_div)) {
            $fileid = $fileid->getValue();
            push(@old_fptrs,$old_xpc->findnodes("//mets:file[\@ID='$fileid']/mets:FLocat/\@xlink:href"));
        }
        foreach my $fileid ($new_xpc->findnodes("./mets:fptr/\@FILEID",$new_div)) {
            $fileid = $fileid->getValue();
            push(@new_fptrs,$new_xpc->findnodes("//mets:file[\@ID='$fileid']/mets:FLocat/\@xlink:href"));
        }
        $self->assert_equal(scalar(@old_fptrs),scalar(@new_fptrs),
            "file count for mets:div\@ORDER=$order");

        foreach my $attribute ($old_div->attributes()) {
            $self->assert_equal($attribute->getValue(),
                $new_div->getAttribute($attribute->nodeName()), $attribute->nodeName());
        }

        foreach my $attribute ($new_div->attributes()) {
            $self->assert_equal($attribute->getValue(),
                $old_div->getAttribute($attribute->nodeName()), $attribute->nodeName());
        }

        @old_fptrs = sort(map { $_->getValue() } @old_fptrs);
        @new_fptrs = sort(map { $_->getValue() } @new_fptrs);
         pairwise { $self->assert_equal($a,$b,"div\@ORDER='$order' file") }
            (@old_fptrs, @new_fptrs);

    }

    # move old METS aside
    my $mets_source = $volume->get_mets_path();
    my $mets_dest = $volume->get_repository_mets_path();
    my $mets_old;
    if($mets_dest =~ /\.mets\.xml$/) {
        $mets_old = $mets_dest;
        $mets_old =~ s/\.mets\.xml$/.pre_uplift.mets.xml/;
    } else {
        $self->set_error("BadFile",file=>$mets_dest,detail=>"Unexpected file name for METS in repository",expected=>"*.mets.xml");
    }

    # move new METS into place
    if (-f $mets_source and -f $mets_dest and defined $mets_old){
        # move mets and zip to repo
        system('cp','-f',$mets_dest,$mets_old)
            and $self->set_error('OperationFailed', operation => 'cp', detail => "cp $mets_dest $mets_old failed with status: $?");
            
        system('cp','-f',$mets_source,$mets_dest)
            and $self->set_error('OperationFailed', operation => 'cp', detail => "cp $mets_source $mets_dest failed with status: $?");

        $self->_set_done();
        return $self->succeeded();
    }
    
}

sub clean_always {
    my $self = shift;

    $self->{volume}->clean_unpacked_object();
    $self->{volume}->clean_mets();
    $self->{volume}->clean_zip();
}

sub clean_success {
    my $self = shift;
    $self->{volume}->clear_premis_events();
}

sub stage_info {
   return { success_state => 'uplift_done', failure_state => 'punted' };
}

sub assert_equal {
    my $self= shift;
    my ($old_val,$new_val,$field) = @_;
    get_logger->trace("field: $field, $new_val = $old_val ?");
    if(not defined $old_val or not defined $new_val or $old_val ne $new_val) {
        $self->set_error("BadValue",field=>$field,actual=>$new_val,expected=>$old_val,file=>$self->{new_mets_file});
        return 0;
    }
    return 1;
}

# page data gatherer that uses page info from existing repository METS and does

sub get_page_data_repository_mets {

    my $self = shift;
    my $file = shift;
    my $xc   = $self->{old_xpc};

    if(not defined $self->{page_data}) {
        my $page_data = {};
        # Extract info from the physical structmap
        foreach my $page ($xc->findnodes('//METS:structMap/METS:div/METS:div')) {

            my $pagenum = $page->getAttribute('ORDERLABEL');
            my $tags = $page->getAttribute('LABEL');

            foreach my $fptr ( $page->getChildrenByTagNameNS( NS_METS, 'fptr' ) )
            {
                my $fileid = $fptr->getAttribute('FILEID');
                my $filename = $xc->findvalue(qq(//METS:file[\@ID='$fileid']/METS:FLocat/\@xlink:href));
                $page_data->{$filename} = {
                    orderlabel => $pagenum,
                    label      => $tags,
                };
            }
        }
        $self->{page_data} = $page_data;
    }

    return $self->{page_data}{$file};

}

1;
