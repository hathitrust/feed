#!/usr/bin/perl

use warnings;
use strict;
use Term::ReadKey;

use Getopt::Long;
use Pod::Usage;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use HTFeed::Log { root_logger => 'ERROR, dbi' };
use HTFeed::Version;

use HTFeed::DBTools qw(get_dbh);
use HTFeed::Config;
use HTFeed::Dataset::Tracking;
use HTFeed::Dataset::RightsDB;
use HTFeed::RunLite qw( runlite runlite_finish );
use HTFeed::Dataset::Subset qw( update_subsets );

# which sets to run on
my ($all,$full,$sub);

my $reingest = 1;
my $updates = 1;
my $delete = 1;
my $verbose = 1;
my $threads = 0;

my $write_fullset_id_file = 0;

my $help;
GetOptions(
    'all'       => \$all,
    'full'      => \$full,
    'sub'       => \$sub,
    'reingest!' => \$reingest,
    'updates!'  => \$updates,
    'delete!'   => \$delete,
	'verbose!'  => \$verbose,
    'fullid'    => \$write_fullset_id_file,
    'help|?'    => \$help,
    'threads=i' => \$threads
) or pod2usage(2);
pod2usage(1) if $help;

# need to have something to do
pod2usage(2)
    unless($all or $full or $sub or $delete);

# get optional list of subsets for update
my @subset_names;
if ($sub) {
    while (my $name = shift){
        push @subset_names, $name;
    }
}

# delete volumes that no longer fit rights criteria
if($delete) {
    my $volumes = HTFeed::Dataset::RightsDB::get_bad_volumes();
    $write_fullset_id_file += $volumes->size();

    HTFeed::Volume::set_stage_map({'ready' => 'HTFeed::Dataset::Stage::Delete'});
    runlite(volumegroup => $volumes, logger => 'HTFeed::Dataset::delete', verbose => $verbose);
    runlite_finish();
    HTFeed::Volume::clear_stage_map();

} else {
    print <<"WARNING";
Running an update without running deletes is not recommended, and should only
be done if you understand the ramifications and have good reason to do it.
If you understand this warning and still want to continue, type "yes" and hit
<return> within 15 seconds. Otherwise, press <return>, or wait for the timeout
to exit.
WARNING

    my $answer = _timed_input(15);
    unless ($answer eq "yes\n") {
		print "Exiting\n";
        exit 2;
    }
	print "Continuing\n";
}

# do sub and full if --all is set
# NOTE: --all is not exactly the same as --full --sub, as following SETNAME args are ignored
if ($all) {
    $sub = 1;
    $full = 1;
}

# update fullset
if ($full) {
    # set dataset ingest pipeline
    HTFeed::Volume::set_stage_map({'ready'    => 'HTFeed::Dataset::Stage::UnpackText',
                                   'unpacked' => 'HTFeed::Dataset::Stage::Pack',
                                   'packed'   => 'HTFeed::Dataset::Stage::Collate'});

    # update outdated volumes
    if ($reingest) {
        print "Identifying outdated volumes...\n";
        my $outdated_volumes = HTFeed::Dataset::Tracking::get_outdated();

        runlite(volumegroup => $outdated_volumes, logger => 'HTFeed::Dataset::update_outdated', verbose => $verbose, threads => $threads);
        runlite_finish();
    }

    # add missing volumes
    if ($updates) {
        print "Identifying missing volumes...\n";
        my $missing_volumes = HTFeed::Dataset::RightsDB::get_fullset_missing_volumegroup();

        $write_fullset_id_file += $missing_volumes->size();

        runlite(volumegroup => $missing_volumes, logger => 'HTFeed::Dataset::update_missing', verbose => $verbose, threads => $threads);
        runlite_finish();
    }

    # clear custom Stage Map
    HTFeed::Volume::clear_stage_map();
}

# write new id file if any volumes were added or deleted in the fullset
if ($write_fullset_id_file) {
    my $datasets_location = get_config('dataset'=>'path');
    my $fullset_name      = get_config('dataset'=>'full_set');

    my $full_set_id_file = "$datasets_location/id/$fullset_name.id";
    my $full_set_id_file_link = "$datasets_location/$fullset_name/obj/id";

    if (-e $full_set_id_file_link) {
        unlink $full_set_id_file_link or die "unlinking $full_set_id_file_link failed";
    }
    if (-e $full_set_id_file) {
        unlink $full_set_id_file or die "unlinking $full_set_id_file failed";
    }

    # write id file
	# TODO: use global verbose flag to silence this
	print "writing id file: $full_set_id_file\n";

    my $fullset_vg = HTFeed::Dataset::Tracking::get_all();
    $fullset_vg->write_id_file($full_set_id_file);

    symlink $full_set_id_file,$full_set_id_file_link or die "Cannot make link $full_set_id_file_link";
}

# update subsets
if ($sub) {
    # get subsets
    update_subsets(@subset_names);
}

# _time_input($time)
# reads input until newline or $time seconds
sub _timed_input {
    my $end_time = time + shift;
    my $string;
    my $key;
    do {
        $key = ReadKey(1);
        $string .= $key if defined $key;
    } while (time < $end_time and (!(defined $key) or $key ne "\n"));
    return $string
};


__END__

=head1 NAME

update_datasets.pl - update HathiTrust datasets

=head1 SYNOPSIS

update_datasets.pl < --nodelete > < --all | --full [--no-reingest | --no-updates] | --sub [SETNAME [SETNAME ...]] >

--all - update all sets, overrides alll other options

--full - update full set

--sub - update subsets, specify SETNAME to only update a particular subset, otherwise all sets are updated

--no-delete - do not run deletes before set update

--no-reingest, --no-updates - use with --full flag to skip updating missing or outdated volumes respectively

=cut
