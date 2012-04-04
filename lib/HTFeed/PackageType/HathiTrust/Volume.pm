package HTFeed::PackageType::HathiTrust::Volume;

use warnings;
use strict;

use base qw(HTFeed::Volume);
use HTFeed::Config;
use File::Pairtree qw(id2ppath s2ppchars);

=item get_file_groups 

Returns a hash of HTFeed::FileGroup objects containing info about the logical groups
of files in the objects. Configure through the filegroups package type setting.

=cut

sub get_file_groups {
    my $self = shift;

    if(not defined $self->{filegroups}) {
        my $filegroups = {}; 

        my $nspkg_filegroups = $self->{nspkg}->get('filegroups');
        my $xpc = $self->get_repository_mets_xpc();
        
        while( my ($key,$val) = each (%{ $nspkg_filegroups })) {
            my $files = [];

            my $use = $val->{use};
            my $node_list = $xpc->find(qq{/METS:mets/METS:fileSec/METS:fileGrp[\@USE="$use"]/METS:file/METS:FLocat/\@xlink:href});
            while(my $node = $node_list->shift){
                my $file = $node->nodeValue;
                push @$files,$file;
            }

            $filegroups->{$key} = new HTFeed::FileGroup($files,%$val);
        }
        $self->{filegroups} = $filegroups;
    }

    return $self->{filegroups};
}

## TODO: find source mets
sub get_source_mets_file{
   return;
}

#sub extract_source_mets {
#    
#}

# Don't record any premis events for dataset generation
sub record_premis_event {
    return;
}

sub get_dataset_path {
    my $self = shift;

    if(not defined $self->{dataset_path}) {
        my $datasets_path = get_config('dataset'=>'path');
        my $full_set_name = get_config('dataset'=>'full_set');

        my $namespace = $self->get_namespace();

        my $objid = $self->get_objid();

        my $pairtree_path = id2ppath($objid);

        my $pt_objid = $self->get_pt_objid();

        my $path = "$datasets_path/$full_set_name/obj/$namespace/$pairtree_path/$pt_objid";
        $self->{dataset_path} = $path;
    }

    return $self->{dataset_path};
}

sub get_last_ingest_date{
    my $self = shift;
    
    if(not defined $self->{ingest_date}) {

        my $mets = $self->get_repository_mets_xpc();
        unless($mets){
            ##warn "no mets!";
            return;
        }

        my @dates;
        foreach my $event ($mets->findnodes('//premis:event[premis:eventType="ingestion"] | //premis1:event[premis1:eventType="ingestion"]')) {
            my $date = $mets->findvalue('./premis:eventDateTime | ./premis1:eventDateTime',$event);
            push @dates, $date;
        }
        @dates = sort @dates;
        $self->{ingest_date} = pop @dates;
    }

    return $self->{ingest_date};
}


1;

__END__
