use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use HTFeed::DBTools qw(get_dbh);
use HTFeed::Dataset;
use HTFeed::Volume;

use HTFeed::StagingSetup;
use HTFeed::Version;

use Getopt::Long;

my $pid = $$;

my $get_partitions = 0;
my ($start_date,$end_date);

GetOptions ("generate=i" => \$get_partitions,
            "start=s"    => \$start_date,
            "end=s"      => \$end_date          ) or die;


# generate base query for finding pd volumes in rights_current
my $rights_current_base_q = 'mdp.rights_current WHERE ';
# limit by namespace
#$rights_current_base_q   .= '(namespace = \'' . (join '\' OR namespace = \'', @ns) . '\') AND '
#    if (@ns);
# limit by soucre (non-google)
$rights_current_base_q   .= 'source != 1 AND ';
# limit by attr (pd, pdus, cc, etc)
$rights_current_base_q   .= '(attr = 1 OR attr = 7 OR (attr > 8 AND attr < 16))';


#### 
# Handle -g (generate partitioned commands) flag
#
####
if ($get_partitions){

    die "Number of partitions must be an integer value greater than 1" unless ($get_partitions =~ /^\d+$/ and $get_partitions > 1);
    
    # count rows in current_rights
    my $sth = get_dbh()->prepare("SELECT COUNT(*) FROM $rights_current_base_q");
    $sth->execute;
    my ($rights_current_count) = $sth->fetchrow_array;
    my $partition_size;
    {   
        use integer;
        $partition_size = $rights_current_count / $get_partitions;
    }
    my $partition_index_cnt = $get_partitions - 1;
    
    my @commands;
    {
        my @partition_indexes;
        {
            my $index = 0;
            foreach my $i (1..$partition_index_cnt){
                $index += $partition_size;
                push @partition_indexes, $index; 
            }
        }

        my @partition_dates;
        my $sth = get_dbh()->prepare("SELECT time FROM $rights_current_base_q ORDER BY time LIMIT ?,1");        
        foreach my $index (@partition_indexes){
            $sth->execute($index);
            my ($date) = $sth->fetchrow_array;
            push @partition_dates, $date;
        }
        
        {
            my $start_date;
            my $end_date;
            
            foreach (1..$get_partitions){
                $start_date = $end_date;
                $end_date = shift @partition_dates;
                
                my $command = $0;
                $command .= qq{ -s "$start_date"} if $start_date;
                $command .= qq{ -e "$end_date"} if $end_date;
                
                push @commands, $command;
            }
        }
    }
    
    print join("\n", @commands) . "\n";
    exit 0;
}

#### 
# default operation - process volume a dditions for specified date range
####

HTFeed::StagingSetup::make_stage(1);

my $kids = 0;
my $max_kids = 0;

# get namespace,id for selected date range
my $rights_current_date_range_q = "SELECT namespace,id FROM $rights_current_base_q";
$rights_current_date_range_q   .= " AND time >= ?" if $start_date;
$rights_current_date_range_q   .= " AND time < ?" if $end_date;

my $sth = get_dbh()->prepare($rights_current_date_range_q);
{
    my @rights_current_date_range_args;
    push @rights_current_date_range_args, $start_date if $start_date;
    push @rights_current_date_range_args, $end_date if $end_date;
    $sth->execute(@rights_current_date_range_args);
}

while (my ($ns,$id) = $sth->fetchrow_array()){
    my $volume = HTFeed::Volume->new(
        objid       => $id,
        namespace   => $ns,
        packagetype => 'ht',
    );
    
    # Fork iff $max_kids != 0
    if($max_kids){
        spawn_volume_adder($volume);
    }
    else{
        # not forking
        HTFeed::Dataset::add_volume($volume);
    }
}
while($kids){
    wait();
    $kids--;
}

# add_volume
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
        HTFeed::Dataset::add_volume($volume);
        exit(0);
    }
    else {
        die "Couldn't fork: $!";
    }
}

END{
    HTFeed::StagingSetup::clear_stage()
        if ($$ eq $pid);
}
