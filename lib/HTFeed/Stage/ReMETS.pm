#!/usr/bin/perl

package HTFeed::Stage::ReMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use List::MoreUtils qw(pairwise);
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

    my $pkg_type = $volume->get_nspkg();
    my $pkg_class = ref($pkg_type);
    no strict 'refs';
    my $pkg_config = ${"${pkg_class}::config"};
    $pkg_config->{premis_events} = [
        'premis_migration',
        'mets_update'
    ];

    $volume->record_premis_event('mets_update');
    # run original METS stage
    my $mets_class = $volume->next_stage('packed');
    my $mets_stage =  eval "$mets_class->new(volume => \$volume)";
    $mets_stage->run();

    # assure success
    if($mets_stage->succeeded()) {
        $self->_set_done();
    }

    # compare new METS to old mets. must have:

    my $new_mets_file = $mets_stage->{outfile};
    $self->{new_mets_file} = $new_mets_file;
    my $old_xpc = $volume->get_repository_mets_xpc();
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
    foreach my $event_type_node ($old_xpc->findnodes("//premis:eventType")) {
        my $event_type = $event_type_node->textContent();

        my $query = "count(//premis:eventType[text()='$event_type']";
        my $old_event_count = $old_xpc->findvalue($query);
        my $new_event_count = $new_xpc->findvalue($query);
        $self->assert_equal($old_event_count,$new_event_count,"count($query)");
    }

    # verify mapping of PREMIS1 events??

    # for each //mets:file
    #   the //mets:file with that ID in the new METS must have the same attributes except CREATED
    #     the mets:FLocat/xlink:href must match as well
    foreach my $old_file ($old_xpc->findnodes("//mets:file")) {
        my $file_name = $old_xpc->findvalue('./mets:FLocat/@xlink:href',$old_file);
        my $new_file = ($new_xpc->findnodes("//mets:file[mets:FLocat/\@xlink:href='$file_name']"))[0];

        foreach my $attribute ($old_file->attributes(), $new_file->attributes()) {
            my $attr_name = $attribute->nodeName();
            next if lc($attr_name) eq 'created';
            my $old_attr = $old_file->getAttribute($attr_name);
            my $new_attr = $new_file->getAttribute($attr_name);
            $self->assert_equal($old_attr,$new_attr,"$file_name $attr_name");
        }
    }

    # for each //mets:div
    #   the corresponding //mets:div must have the same LABEL 
    #   and ORDERLABEL and the set of fptrs must point to the same files
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


        @old_fptrs = sort(map { $_->getValue() } @old_fptrs);
        @new_fptrs = sort(map { $_->getValue() } @new_fptrs);
         pairwise { $self->assert_equal($a,$b,"div\@ORDER='$order' file") }
            (@old_fptrs, @new_fptrs);

    }

    # move old METS aside
    # move new METS into place

    # remap success output stage


}

sub clean_always {
    my $self = shift;

    $self->{volume}->clean_unpacked_object();
}

# do cleaning that is appropriate after failure
sub clean_failure {
    my $self = shift;
    $self->{volume}->clean_mets();
}

sub stage_info {
   return { success_state => 'done', failure_state => 'punted' };
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

1;
