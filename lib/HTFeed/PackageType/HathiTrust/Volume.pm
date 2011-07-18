package HTFeed::PackageType::HathiTrust::Volume;

use warnings;
use strict;

use base qw(HTFeed::Volume);
use HTFeed::Config;
use File::Pairtree;

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

## TODO: this
#sub extract_source_mets {
#    die "!"
#}

## TODO: find source mets
sub get_source_mets_file{
    return;
}

# Don't record any premis events for dataset generation
sub record_premis_event {
    return;
}

sub get_dataset_path {
    my $self = shift;

    if(not defined $self->{dataset_path}) {
        my $dataset_repo = get_config('dataset'=>'repository');
        my $namespace = $self->get_namespace();

        my $objid = $self->get_objid();

        my $pairtree_path = id2ppath($objid);

        my $pt_objid = $self->get_pt_objid();

        my $path = "$dataset_repo/$namespace/$pairtree_path/$pt_objid";
        $self->{dataset_path} = $path;
    }

    return $self->{dataset_path};
}

1;

__END__
