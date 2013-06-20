#!/usr/bin/env perl

# subset info
# list current datasets and stats

use warnings;
use strict;
use v5.10.1;

use HTFeed::Config;
use HTFeed::Dataset::Subset;

my @subset_list = HTFeed::Dataset::Subset::get_subset_config();

# print set name, size, last build date
say "Last Update\tVolumes\tName";
my $datasets_location = get_config('dataset'=>'path');
foreach my $set (get_config('dataset'=>'full_set'), @subset_list) {
    my $set_path        = "$datasets_location/$set/obj";
    my $id_list_link    = "$set_path/id";
    my $metadata_link   = "$set_path/meta.tar.gz";
    my $id_list_file    = (-l $id_list_link and readlink $id_list_link);
    my $metadata_file   = (-l $metadata_link and readlink $metadata_link);
    my $id_list_exists  = ($id_list_file and -f $id_list_file);
    my $metadata_exists = ($metadata_file and -f $metadata_file);
    my $id_list_size    = ($id_list_exists and `wc -l $id_list_file | cut -f1 -d' '`);
    $id_list_size //= 0;
    chomp $id_list_size;
    $id_list_size ||= 0;
    my $id_list_date;
    $id_list_date = `stat -c "%y" $id_list_file | cut -f1 -d' '`
        if $id_list_size;
    chomp $id_list_date if $id_list_date;
    $id_list_date //= '0000-00-00';
    
    say "$id_list_date\t$id_list_size\t$set";
}
