package HTFeed::DBTools::Priority;

=description
    Queries relating to prioritization
    
=explanation of priority field
    lowest number is first in the queue (after priority we order on insert date)
    
    0 indicates ingest immediately
    group priorities are integers >= 100 (e.g. 14200)
    except for the special priorites of first and last priority = group_priority + x, where x is a priority within the group
    x is 0 (first in group) 1 (normal) or 2 (last in group)
=cut

use warnings;
use strict;
use Carp;
use base qw(HTFeed::DBTools);

our @EXPORT = qw(priority);
#our @EXPORT_OK = qw(reprioritize set_group_priorities);

=item priority
get the priority for a volume or ns + pkg_type
=synopsis
my $priority = priority($volume,$modifier);
my $priority = priority($ns,$pkg_type,$modifier);

valid modifiers are:
first, last, group_first, group_last

max group_priority = 2^20 * 100 - 100
review this once we have a million partners
=cut
sub priority{
    my ($ns,$pkg_type);
    my ($arg1) = @_;
    if (ref $arg1){
        my $volume = shift;
        $ns = $volume->get_namespace();
        $pkg_type = $volume->get_packagetype();
    }
    else{
        $ns = shift;
        $pkg_type = shift;
    }
    my $modifier = shift;
    
    my $get_group_priority = get_dbh()->prepare(q(SELECT MIN(priority_number) FROM priority WHERE (namespace = ? AND pkg_type IS NULL) OR (namespace IS NULL AND pkg_type = ?) OR (namespace = ? AND pkg_type = ?);));

    # each var bound twice to accomadate wacky SQL
    $get_group_priority->execute($ns,$pkg_type,$ns,$pkg_type);
    my ($group_priority) = $get_group_priority->fetchrow_array();
    
    $group_priority = 2^20 * 100 if (! defined $group_priority)
    
    my $priority = 0;
    switch ($modifier){
        case 'first'        { $priority = 0 }
        case 'last'         { $priority = 2^31 }
        case 'group_first'  { $priority = $group_priority }
        case 'group_last'   { $priority = $group_priority + 2 }
        else                { $priority = $group_priority + 1 }
    }
    
    return $priority;
}

#sub reprioritize{
#    my %priority_cache = ();
#    
#    my $get_all_ready
#}
#
#sub set_group_priorities{
# 
#}

1;

__END__
