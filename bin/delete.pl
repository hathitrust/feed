#!/usr/bin/perl

use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;

my $deletekey = get_config('deletekey');

get_deletion_confirmation() or die();

print STDERR "MANUALLY Enter IDs to delete, one per line:\n";

while(<>) {
    print STDERR "id> ";
    my $id = shift;
    my ($namespace,$objid) = split(/\./,$id);

    my $volume = new HTFeed::Volume(namespace => $namespace, objid => $objid, package_type => 'ht');

    # add to blacklist
    
    # remove from queue (if present)

    # create tombstone

    # set rights to nobody/del

    # final confirmation before deleting data from repository 
    
    # delete zip, put tombstone in place

}


sub add_to_blacklist {
    my $volume = shift;

    # get blacklist reason
    # add to blacklist
}

sub remove_from_queue {
    my $volume = shift;

    # remove from queue
}

sub tombstone {
    my $volume = shift;

    # add PREMIS deletion event
    # strip filesecs
    # strip structmap
    # revalidate
    # move into place
}

sub update_rights {
}

sub remove_zip {
}

sub get_deletion_confirmation { 
    if(not defined $deletekey or ! -e $deletekey) {
        die("The deletion key has not been inserted.\n");
    }

    print STDERR <<EOT;

Deletions from the repository may only be performed with the direct
authorization of the Executive Director of HathiTrust. Proceed with
extreme care! 

EOT

    print STDERR "Press Ctrl-C within 10 seconds to abort";

    for(my $i = 0; $i < 10; $i++) {
        sleep 1;
        print STDERR ".";
    }
    print STDERR "\n\n";


    print STDERR <<EOT;
You must enter the following text verbatim to continue:

'Proceed with deleting volumes from HathiTrust.'

EOT

    print "> ";
    my $confirm = <>;
    chomp($confirm);
    if($confirm ne 'Proceed with deleting volumes from HathiTrust.') {
        print "You did not correctly enter the confirmation text; exiting.\n";
        exit(1);
    }

    print STDERR "\nLast chance to abort -- press Ctrl-C within 10 seconds";
    for(my $i = 0; $i < 10; $i++) {
        sleep 1;
        print STDERR ".";
    }
    print STDERR "\n\n";

    return 1;
}

unlink($deletekey);
print "The deletion key has been ejected.\n";
