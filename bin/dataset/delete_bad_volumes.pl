#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use HTFeed::Config;
use HTFeed::Dataset::RightsDB;

my $volumes = get_bad_volumes(@{get_config('dataset'=>'full_set_rights_query')});

while (my $nsid = shift @{$volumes}){
    my ($ns,$id) = @{$nsid};
    
    my $volume;
    eval{
        $volume = HTFeed::Volume->new(
            objid       => $id,
            namespace   => $ns,
            packagetype => 'ht',
        );
    };
    if($@){
        # bad barcode
        warn "skipped $ns.$id, could not instantiate volume";
        next;
    }
    eval{
        Dataset::remove_volume($volume);
    }
    if($@){
        warn "$ns.$id delete failed $@";
    }
}
