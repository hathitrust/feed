#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Log { root_logger => 'INFO, screen' };
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Volume;
use HTFeed::XMLNamespaces qw(:namespaces);
use HTFeed::METS;
use XML::LibXML;
use POSIX qw(strftime);
use PREMIS;

my $deletekey = get_config('deletekey');
my $note = '';
my $user = '';
my $reason = '';

get_deletion_confirmation() or die();



# get blacklist reason
while($user eq '') {
    print "Enter the uniqname of the responsible party.\n";
    print "> ";
    $user = <>;
    chomp($user);
}
# get blacklist reason
while($note eq '') {
    print "Enter a brief note describing why these volumes are being deleted.\n";
    print "> ";
    $note = <>;
    chomp($note);
}
# get delete reason
while($reason !~ /^quality|takedown|identifier$/) {
    print "Enter the reason this deletion falls under:\n";
    print "  quality: Volume being deleted for quality reasons; cannot improve or better copy is in repository\n";
    print "  takedown: Takedown requested by copyright holder\n";
    print "  identifier: Volume in repository with incorrect identifier\n";
    print "quality|takedown|identifier> ";
    $reason = <>;
    chomp $reason;
}

my $today = strftime("%Y%m%d",localtime());

open(RIGHTS,">>delete_$today.rights") or die("Can't open rights file: $!");

print STDERR "MANUALLY Enter IDs to delete, one per line, or 'quit' to exit:\n";

while(1) {
    print STDERR "id> ";
    my $id = <>;
    last if not defined $id;
    chomp $id;
    last if $id eq 'quit' or $id eq 'exit' or $id eq '';
    my ($namespace,$objid) = split(/\./,$id,2);

    my $volume = new HTFeed::Volume(namespace => $namespace, objid => $objid, package_type => 'ht');

    # add to blacklist
    add_to_blacklist($volume,$note);

    # remove from queue (if present)
    remove_from_queue($volume);

    # create tombstone
    tombstone($volume,$note);

    # set rights to nobody/del
    print RIGHTS "$namespace.$objid\tnobody\tdel\t$user\n";

    # delete zip, put tombstone in place
    remove_zip($volume);
    print "Successfully deleted $namespace.$objid\n";

}

print "Remember to set the rights for these volumes to nobody/del. A file
called delete_$today.rights has been created that you can rename and load.\n";


sub add_to_blacklist {
    my $volume = shift;
    my $note = shift;
    die("Must have a reason for blacklisting") if not defined $note or $note eq '';
    my $sth = get_dbh()->prepare("INSERT IGNORE INTO feed_blacklist (namespace, id, note) VALUES (?,?,?)");
    $sth->execute($volume->get_namespace(),$volume->get_objid(),$note);
}

sub remove_from_queue {
    my $volume = shift;

    my $sth = get_dbh()->prepare("DELETE FROM feed_queue WHERE namespace = ? and id = ?");
    $sth->execute($volume->get_namespace(),$volume->get_objid());
}

sub tombstone {
    my $volume = shift;
    my $mets_xpc = $volume->get_repository_mets_xpc();

    # add premis event!
    # <PREMIS:event>
    #     <PREMIS:eventIdentifier>
    #         <PREMIS:eventIdentifierType>UUID</PREMIS:eventIdentifierType>
    #         <PREMIS:eventIdentifierValue>FD713DBB-F0A6-3E56-9101-9DA007D45047</PREMIS:eventIdentifierValue>
    #     </PREMIS:eventIdentifier>
    #     <PREMIS:eventType>deletion</PREMIS:eventType>
    #     <PREMIS:eventDateTime>2010-12-22T15:07:26</PREMIS:eventDateTime>
    #     <PREMIS:eventDetail>Deletion of content data object from repository</PREMIS:eventDetail>
    #     <PREMIS:eventOutcomeInformation>
    #         <PREMIS:eventOutcomeDetail>
    #             <PREMIS:eventOutcomeDetailExtension>
    #                 <ht:deleteReason>quality</ht:deleteReason>
    #             </PREMIS:eventOutcomeDetailExtension>
    #             <PREMIS:eventOutcomeDetailNote>
    #                 Removed for quality reasons: pages 88-89 missing.
    #             </PREMIS:eventOutcomeDetailNote>        
    #         </PREMIS:eventOutcomeDetail>
    #     </PREMIS:eventOutcomeInformation>
    #     <PREMIS:linkingAgentIdentifier>
    #         <PREMIS:linkingAgentIdentifierType>MARC21 Code</PREMIS:linkingAgentIdentifierType>
    #         <PREMIS:linkingAgentIdentifierValue>MiU</PREMIS:linkingAgentIdentifierValue>
    #         <PREMIS:linkingAgentRole>Executor</PREMIS:linkingAgentRole>
    #     </PREMIS:linkingAgentIdentifier>
    # </PREMIS:event>
    my $delete_date = $volume->_get_current_date();
    my $eventid = $volume->make_premis_uuid('deletion',$delete_date);
    my $delete_event = new PREMIS::Event($eventid,'UUID','deletion',$delete_date,'Deletion of content data object from repository');
    my $outcome = new PREMIS::Outcome();

    $outcome->add_detail_note($note);

    # add delete reason
    my $detail = $outcome->{'detail'}[0];
    my $ext_node = PREMIS::createElement("eventOutcomeDetailExtension");
    $detail->appendChild($ext_node);
    my $reason_node = new XML::LibXML::Element("deleteReason");
    $reason_node->setNamespace(NS_HT,'HT');
    $reason_node->appendText($reason);
    $ext_node->appendChild($reason_node);

    $delete_event->add_outcome($outcome);


    # always just use michigan for the capture event.
    $delete_event->add_linking_agent(
        new PREMIS::LinkingAgent( 'MARC21 Code',
            'MiU',
            'Executor' ) );

    my $premis_mdsec;
    if (($premis_mdsec) = $mets_xpc->findnodes('//mets:mdWrap[@MDTYPE="PREMIS"]/METS:xmlData/PREMIS:premis')) {
        # PREMIS2: leave as is
        $premis_mdsec->appendChild($delete_event->to_node());

    } else {
        die("Can't find PREMIS section");
    }


    # strip filesecs
    foreach my $node ($mets_xpc->findnodes('//mets:fileSec')) {
        $node->removeChildNodes();
        $node->addNewChild(NS_METS,"fileGrp");
    }

    # strip structmap
    foreach my $node ($mets_xpc->findnodes('//mets:structMap')) {
        $node->removeChildNodes();
        $node->addNewChild(NS_METS,"div");
    }
    # fix up schemaLocation if necessary
    my ($mets_top) = $mets_xpc->findnodes('//mets:mets');
    my $schemaLocation = $mets_top->getAttribute('xsi:schemaLocation');
    my @tokens = split(/\s*/,$schemaLocation);
    if(@tokens % 2 != 0 and $tokens[-1] eq 'http://purl.org/dc/elements/1.1/') {
        pop(@tokens);
        $mets_top->setAttribute('xsi:schemaLocation',join(' ',@tokens));
    }

    # save to tmp location
    my $mets_filename = $volume->get_pt_objid(). ".mets.xml";
    open( my $metsxml, ">", "/tmp/$mets_filename" )
        or die("Can't open METS xml /tmp/$mets_filename for writing: $!");
    print $metsxml $mets_top->toString(1);
    close($metsxml);

    # revalidate
    my ( $mets_valid, $val_results ) = HTFeed::METS::validate_xml({volume => $volume},"/tmp/$mets_filename");
    if ( !$mets_valid ) {
        die( "Error validating tombstone /tmp/$mets_filename: $val_results");
    }
}

sub remove_zip {
    my $volume = shift;

    my $zip = $volume->get_repository_zip_path();
    die("Couldn't get zip from " . $volume->get_namespace() . "." . $volume->get_objid())
    unless defined $zip and $zip;

    unlink($zip) or die("Couldn't unlink $zip: $!");

    # move tombstone into place
    my $mets_filename = $volume->get_pt_objid(). ".mets.xml";
    my $repos_mets_location = $volume->get_repository_mets_path();
    system("mv /tmp/$mets_filename $repos_mets_location") and die("moving tombstone into place failed with exit status $?");


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
