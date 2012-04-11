package HTFeed::PackageType::HathiTrust::Volume;

use warnings;
use strict;

use base qw(HTFeed::Volume);
use HTFeed::Config;
use File::Pairtree qw(id2ppath s2ppchars);
use IO::Uncompress::Unzip qw(unzip $UnzipError);
## possibly move to a require for packaging
use HTFeed::XMLNamespaces qw(register_namespaces);

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

# checksums for repo volume should come from repo mets
sub _checksum_mets_xpc {
    my $self = shift;
    return $self->get_repository_mets_xpc();
}

=item get_source_mets_file

Return false, because we can't establish a useful path for this without
extracting to a stating directory. This override is only here to prevent
unexpected behavior and may change in the future. Do not rely on the
current behavior.

=cut
sub get_source_mets_file{
    return;
}

=item get_source_mets_xpc

Return source_mets_xpc if possible. Returns false if file is not found.

=cut
sub get_source_mets_xpc {
    my $self = shift;
    my $mets_content = $self->get_source_mets_string() or return;
    my $xpc;

    eval {
        my $parser = XML::LibXML->new();
        my $doc = $parser->parse_string($mets_content);
        $xpc = XML::LibXML::XPathContext->new($doc);
        register_namespaces($xpc);
    };
    if ($@) {
        warn "source mets xml parsing failed";
    } else {
        return $xpc;
    }

    return;
}

=item get_source_mets_string

Attempt to extract source METS to a string and return.
Returns false if file is not found.

=cut
sub get_source_mets_string {
    my $self = shift;
    my $zip = $self->get_repository_zip_path();

    my $mets_xpc_filestream_name;
    # shell out to get streamname, because Archive::Zip because it doesn't handle
    # ZIP64 and IO::Uncompress::Unzip handling of uncompressed streams is broken
    # until IO-Compress-2.030
    foreach my $line (split '\n', `unzip -j -qq -l $zip '*.xml'`) {
        chomp $line;
        my @fields = split '\s+', $line;
        my $pathname = pop @fields;
        $pathname =~ /\/([^\/]*)$/;
        my $filename = $1;
        # look for a filename that looks like a mets
        if ($filename =~ /\.xml$/ and $filename !~ /^\d{8}\./){
            $mets_xpc_filestream_name = $pathname;
            last;
        }
    }

    return unless($mets_xpc_filestream_name);
    my $mets_content;
    unzip $zip => \$mets_content, Name => $mets_xpc_filestream_name;

    return $mets_content if($mets_content);
    return;
}

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
