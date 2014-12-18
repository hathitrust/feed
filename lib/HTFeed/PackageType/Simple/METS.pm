#!/usr/bin/perl

package HTFeed::PackageType::Simple::METS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use base qw(HTFeed::METS);


sub _add_techmds {
    my $self = shift;
    $self->SUPER::_add_techmds();
    my $volume = $self->{volume};
    my $xc = $volume->get_source_mets_xpc();

    my $reading_order = new METS::MetadataSection( 'techMD',
        id => $self->_get_subsec_id('TMD'));

    my @mdwraps = $xc->findnodes('//mets:mdWrap[@LABEL="reading order"]');
    if(@mdwraps == 1) {
        my $mdwrap = $mdwraps[0];

        my $mets = $self->{mets};
        $mets->add_schema( "gbs", "http://books.google.com/gbs");
        $reading_order->set_mdwrap($mdwrap);
        push(@{ $self->{amd_mdsecs} },$reading_order);
    } else {
        my $count = scalar(@mdwraps);
        if($count == 0) {
          get_logger->warn("BadField",field=>"reading order",detail=>"No reading order techMD found in source METS; assuming reading-order:left-to-right, scanning-order:left-to-right");
        } else {
          $self->set_error("BadField",field=>"reading order",detail=>"Found $count reading order techMDs, expected 1");
        }
    }
}


1;
