#!/usr/bin/perl

use warnings;
use strict;
use Carp;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use HTFeed::Config;

use File::Pairtree;
use File::Path qw(make_path);

my $datasets_location = get_config('dataset'=>'path');
my $target_tree_name  = get_config('dataset'=>'full_set');
my $link_tree_name    = shift;

my $target_tree = "$datasets_location/$target_tree_name/obj";
my $link_tree   = "$datasets_location/$link_tree_name/obj";

my $volumes_processed = 0;
print "$volumes_processed volumes processed...\n";

while(<>){
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

print "$volumes_processed volumes processed\n";

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
