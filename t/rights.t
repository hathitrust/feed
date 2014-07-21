#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

@ARGV = qw(--force-man --note="test");;;;;;;;
require '../bin/feed.hourly/populate_rights_data.pl';


# pdus/bib and pd/bib override pdus/gfv, ic/bib, and und/bib
rights_override('pdus','bib','ic','bib');
rights_override('pdus','bib','und','bib');
rights_override('pdus','bib','pdus','gfv');
rights_override('pd','bib','ic','bib');
rights_override('pd','bib','und','bib');
rights_override('pd','bib','pdus','gfv');

#pdus/gfv overrides ic/bib and und/bib
rights_override('pdus','gfv','ic','bib');
rights_override('pdus','gfv','und','bib');
rights_not_override('pdus','gfv','pd','bib');
rights_not_override('pdus','gfv','pdus','bib');

#ic/bib and und/bib override pdus/bib and pd/bib
rights_override('ic','bib','pd','bib');
rights_override('und','bib','pd','bib');
rights_override('ic','bib','pdus','bib');
rights_override('und','bib','pdus','bib');
rights_not_override('ic','bib','pdus','gfv');
rights_not_override('und','bib','pdus','gfv');

# non-bib overrides pdus/gfv
rights_override('pd','ren','pdus','gfv');
rights_not_override('pdus','gfv','pd','ren');

# crms determinations
rights_override('ic','unp','pd','ren');
rights_override('und','nfi','pd','exp');
rights_override('pd','ncn','und','nfi');
rights_override('pd','ren','ic','bib');
rights_override('pd','ren','pdus','gfv');
# crms always has precedence even if bib data says pd
rights_not_override('pd','bib','und','nfi');
rights_not_override('pdus','gfv','ic','ren');
rights_override('und','nfi','pd','bib');

# contractual determinations - overrides bib,crms even if pd
rights_override('ic-world','con','pd','bib');
rights_override('nobody','pvt','ic','bib');
rights_override('cc-by-nc-3.0','con','pd','ren');
rights_override('cc-by-nc-nd-4.0','con','pd','bib');
rights_not_override('pd','bib','und-world','con');
rights_not_override('pdus','gfv','cc-by-sa-4.0','con');
rights_not_override('pd','ren','cc-by-sa-3.0','con');

# manual determination
rights_override('pd','man','pd','ren');
rights_override('pd','man','nobody','pvt');
rights_override('nobody','man','pd','man');
rights_not_override('cc-zero','con','ic','man');
rights_not_override('pdus','gfv','ic','man');
rights_not_override('ic','bib','pd','man');
rights_not_override('ic','bib','ic','man');


done_testing();

sub rights_override {
    my ($new_attr, $new_reason, $old_attr, $old_reason) = @_;

    ok(should_update_rights('test','foo',$old_attr,$old_reason,'google',$new_attr,$new_reason,'google'),
        "$new_attr/$new_reason overrides $old_attr/$old_reason");
}

sub rights_not_override {
    my ($new_attr, $new_reason, $old_attr, $old_reason) = @_;

    ok( (not should_update_rights('test','foo',$old_attr,$old_reason,'google',$new_attr,$new_reason,'google')),
        "$new_attr/$new_reason DOES NOT override $old_attr/$old_reason");
}
