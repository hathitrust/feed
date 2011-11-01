#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use HTFeed::Log { root_logger => 'INFO, dbi' };
use Log::Log4perl qw(get_logger);

use HTFeed::StagingSetup;
use HTFeed::Version;

use HTFeed::Dataset;
use HTFeed::Dataset::RightsDB;
use HTFeed::Volume;
use HTFeed::Config;

use Getopt::Long;

my $pid = $$;

# get options
my $load_file;
my $dump_file;
#my $add_missing = 1;
#my $add_outdated = 1;

GetOptions ( 
    "load=s"         => \$load_file, 
    "dump=s"         => \$dump_file,
#    "skip-missing!"  => \$add_missing,
#    "skip-outdated!" => \$add_outdated
) or usage();

# get volume list
my $volumes;

if($load_file){
    $volumes = [];
    
    open(my $id_load, '<', $load_file) or die "cannot open $load_file";
    
    while(<$id_load>){
        chomp;
        my $nsid = $_;
        $nsid =~ /^([^\.]+)\.(.+)$/;
        my $ns = $1;
        my $id = $2;
        push @{$volumes}, [$ns,$id];
    }
}
else{
    $volumes = get_volumes(
    ##    source => 'text',
        source => 'non_google_text',
        attributes => 'pd_us',
        reasons_not => 'google_full_view'
    );
}

if($dump_file){
    open(my $id_dump, '>', $dump_file) or die "cannot open $dump_file";
    
    while (my $nsid = shift @{$volumes}){
        my ($ns,$id) = @{$nsid};
        print $id_dump "$ns.$id\n";
    }
    exit 0;
}

# wipe staging directories
HTFeed::StagingSetup::make_stage(1);

my $volume_count = @{$volumes};
my $volumes_processed = 0;
print "Processing $volume_count volumes...\n";

my $kids = 0;
my $max_kids = get_config('dataset'=>'threads');

while (my $nsid = shift @{$volumes}){
    my ($ns,$id) = @{$nsid};
    
    $volumes_processed++;
    print "Processing volume $volumes_processed of $volume_count...\n"
        unless ($volumes_processed % 1000);
    
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
    
    # Fork iff $max_kids != 0
    if($max_kids){
        spawn_volume_adder($volume);
    }
    else{
        # not forking
        add_volume($volume);
    }
}
while($kids){
    wait();
    $kids--;
}

sub spawn_volume_adder{
    my $volume = shift;
    
    # wait until we have a spare thread
    if($kids >= $max_kids){
        wait();
        $kids--;
    }
    
    my $pid = fork();

    if ($pid){
        # parent
        $kids++;
    }
    elsif (defined $pid){
        add_volume($volume);
        exit(0);
    }
    else {
        die "Couldn't fork: $!";
    }
}

sub add_volume{
    my $volume = shift;
    my $success = 0;
    eval{
        $success = HTFeed::Dataset::add_volume($volume);        
    };
    if($@){
        # record error
        get_logger('HTFeed::Dataset')->error( 'UnexpectedError', objid => $volume->get_objid, namespace => $volume->get_namespace, detail => $@ );
    }
    elsif(!$success){
        get_logger('HTFeed::Dataset')->error( 'UnexpectedError', objid => $volume->get_objid, namespace => $volume->get_namespace, detail => 'did not complete, error unknown' );
    }
}

END{
    HTFeed::StagingSetup::clear_stage()
        if ($$ eq $pid);
}

__END__

=head1 NAME

    update_base_set.pl - upadate base dataset

=head1 Usage

update_base_set.pl [-load id_file] [-dump id_file]

=head1 Synopsis
# ingest ids from list
update_base_set.pl -load id_file

# dump list of ids to ingest
update_base_set.pl -dump id_file
=cut

