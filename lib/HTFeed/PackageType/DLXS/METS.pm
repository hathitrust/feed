#!/usr/bin/perl

package HTFeed::PackageType::DLXS::METS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use base qw(HTFeed::METS);

sub _extract_old_premis {
    my $self = shift;
    my $volume = $self->{volume};
    my $nspkg = $volume->get_nspkg();
    my $xpc = $volume->get_repository_mets_xpc();
    return unless defined $xpc;

    my %premis1_event_map = (
        capture => [qw(capture)],
        compression => [qw(image_compression)],
        'fixity check' => [qw(page_md5_fixity)],
        'ingestion' => [qw(ingestion zip_compression zip_md5_create)],
        'validation' => [qw(package_validation)]
    );

    foreach my $event ($xpc->findnodes('//premis1:event')) {
        my $premis1_type = $xpc->findvalue('./premis1:eventType',$event);
        if(my $eventcodes = $premis1_event_map{$premis1_type}) {
            foreach my $eventcode (@$eventcodes) {
                my $eventconfig = $nspkg->get_event_configuration($eventcode);
                $eventconfig->{date} = $xpc->findvalue('./premis1:eventDateTime',$event);
                $eventconfig->{'eventid'} =  $volume->make_premis_uuid($eventconfig->{'type'},$eventconfig->{'date'});
                # tool is not represented in PREMIS1; don't make up one
                delete $eventconfig->{'tools'};

                my @agents = $xpc->findnodes('./premis1:linkingAgentIdentifier',$event);
                if(@agents != 1) {
                    $self->set_error("BadField",field => "linkingAgentIdentifier",
                        detail => "Expected 1 linking agent, found " . scalar(@agents));
                }
                my $agent = $agents[0];
                my $agentid = $xpc->findvalue('./premis1:linkingAgentIdentifierValue',$agent);
                if($agentid eq 'UM' or $agentid eq 'dlps') {
                    $eventconfig->{'executor_type'} = 'MARC21 Code';
                    $eventconfig->{'executor'} = 'MiU';
                } else {
                    $self->set_error("BadField",field=>"linkingAgentIdentifierValue",
                        actual => $agentid, 
                        detail => "Unknown agent ID");
                }

                $self->add_premis_event($eventconfig);
            }
        }
    }

    # get any PREMIS2 events if they are there..
    return $self->SUPER::_extract_old_premis();
}

1;
