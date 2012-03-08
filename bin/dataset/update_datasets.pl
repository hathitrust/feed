#!/usr/bin/perl

use warnings;
use strict;

use Getopt::Long;
use Pod::Usage;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use HTFeed::DBTools qw(get_dbh);
use HTFeed::Config;
use HTFeed::Datset::Tracking qw(get_outdated);
use HTFeed::Datset::Subset;

# which sets to run on
my ($all,$full,$sub);

my $help;
GetOptions(
    'all'    => \$all,
    'full'   => \$full,
    'sub'  => \$sub,
    'help|?' => \$help,
) or pod2usage(2);
pod2usage(1) if $help;

# must use some flag
pod2usage(2)
    unless($all or $full or $sub);

# get optional list of subsets for update
my @subset_names;
if ($sub){
    while (my $name = shift){
        push @subset_names, $name;
    }
}

# do sub and full if --all is set
# NOTE: --all is not exactly the same as --full --sub, as following SETNAME args are ignored
$sub = 1 and $full = 1
    if($all);

# update fullset
if($full){
    my $outdated_volumes = get_outdated();

    my $runner = HTFeed::LiteStageRunner->new(
            volumes => $outdated_volumes,
            stages => ['HTFeed::Dataset::Stage::UnpackText',
                       'HTFeed::Dataset::Stage::Pack',
                       'HTFeed::Dataset::Stage::Collate']);
                       
    $runner->run();
}

# update subsets
if($full){
    # get subsets
    HTFeed::Dataset::Subset->get_all_subsets(@subset_names);

    foreach my $subset (@{HTFeed::Dataset::Subset->get_all_subsets(@subset_names)}){
        $subset->update;
    }
}

__END__

=head1 NAME

update_datasets.pl - update HathiTrust datasets

=head1 SYNOPSIS

update_datasets.pl <--all | --full | --sub [SETNAME [SETNAME ...]]>

--all - update all sets, overrides alll other options

--full - update full set

--sub - update subsets, specify SETNAME to only update a particular subset, otherwise all sets are updated

=cut
