#!/usr/bin/perl

use warnings;
use strict;
use Carp;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use HTFeed::Config;

use File::Pairtree;
use File::Path qw(make_path);
use File::Copy;

my $datasets_location = get_config('dataset'=>'path');
my $target_tree_name  = get_config('dataset'=>'full_set');
my $trash_dir = get_config('dataset'=>'trash_dir');
my $link_tree_name    = shift;
my $id_list = "$datasets_location/$link_tree_name/id";

my $time = time;

my $target_tree = "$datasets_location/$target_tree_name/obj";
my $link_tree   = "$datasets_location/$link_tree_name/obj.new.$time";
my $link_tree_final = "$datasets_location/$link_tree_name/obj";
my $old_link_tree_final = "$datasets_location/$trash_dir/$link_tree_name.old.$time";

my $volumes_processed = 0;

open(my $id_handle, '<', $id_list) or die "cannot open $id_list";

while(<$id_handle>){
    chomp;
    my ($ns,$objid) = split /\./,$_,2;
    
    eval{
        make_symlink($ns,$objid,$target_tree,$link_tree);
        $volumes_processed++;
        print "$volumes_processed volumes processed...\n" unless($volumes_processed % 1000);
    };
    if($@){
        warn qq(Error on input "$_": $@);
    }
}
close $id_handle;

print "$volumes_processed volumes processed\n";

## move id list to new link tree
## TODO: consider this workflow more
move($id_list, "$link_tree/id");

if(-e $link_tree_final){
    print "moving old link tree out\n";
    move($link_tree_final,$old_link_tree_final);
}
print "moving new link tree in\n";
move($link_tree,$link_tree_final);

=item make_symlink($ns,$objid,$target_tree,$link_tree)

=cut
sub make_symlink {
    my ($ns,$objid,$target_tree,$link_tree) = @_;

    croak "can't make_symlink without all parameters"
        unless ($ns and $objid and $target_tree and $link_tree);

    my ($path,$pt_objid) = get_path($ns,$objid);
    my $target = "$target_tree/$path/$pt_objid";
    my $link = "$link_tree/$path/$pt_objid";
    my $link_path = "$link_tree/$path";

    # check that target exists
    carp "Target $target missing" unless(-d $target);
    # make link dir
    unless(-d $link_path){
        make_path $link_path or croak "Cannot make path $link_path";        
    }
    # link
    symlink $target,$link;
    croak "Cannot make link $link" unless (-l $link);    
}

sub get_path {
    my $namespace = shift;
    my $objid = shift;

    my $pairtree_path = id2ppath($objid);
    chop $pairtree_path; # remove extra '/'
    my $pt_objid = s2ppchars($objid);

    my $path = "$namespace/$pairtree_path";

    return ($path,$pt_objid);   
}

__END__

=description

create a subset of the main dataset from a picklist

=synposis

=cut
