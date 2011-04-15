package HTFeed::DBTools::Priority;

=description
    Queries relating to prioritization
    
=explanation of priority field
    lowest number is first in the queue (after priority we order on insert date)
    
    0 indicates ingest immediately
    group priorities are integers between 1 and 0xFFEF (0xFFF0 and up are reserved)
    priority = 0x10*group_priority + x, where x is a priority within the group
    x is 1 (first in group) 2 (normal) or 3 (last in group)
    
    Reserved priorities:
    0 - First
    0xFFFFxx - Last
    0xFFFExx - Newly added to queue
    0xFFxxxx - reserved for future use
=cut

use warnings;
use strict;
use Carp;
use Switch;
use base qw(HTFeed::DBTools);

our @EXPORT_OK = qw(reprioritize);

=item set_item_priority
set the priority for a volume
=synopsis
my $priority = priority($volume,$modifier);

valid modifiers are:
first, last, group_first, group_last
=cut
sub set_item_priority{
    my $volume = shift;
    my $ns = $volume->get_namespace();
    my $pkg_type = $volume->get_packagetype();
    my $id = $volume->get_objid();
    
    my $modifier = shift;
     
    my $priority = 0;
    switch ($modifier){
        case "first"        { $priority = 0 }
        case "last"         { $priority = 0xFFFFFF }
        case "group_first"  { $priority = group_priority($ns,$pkg_type) * 0x100 + 1 }
        case "group_last"   { $priority = group_priority($ns,$pkg_type) * 0x100 + 2 }
        else                { $priority = group_priority($ns,$pkg_type) * 0x100 + 3 }
    }
    
    my $sth = HTFeed::DBTools::get_dbh()->prepare(q(UPDATE queue SET priority = ? WHERE namespace = ? AND id = ?;));
    
    $sth->execute($priority,$ns,$pkg_type);
    
    return;
}

=item group_priority
get priority for an $ns,$pkg_type
=synopsis
group_priority($ns,$pkg_type)
=cut
sub group_priority{
    my ($ns,$pkg_type) = @_;
    my $get_group_priority = HTFeed::DBTools::get_dbh()->prepare(q(SELECT MIN(priority) FROM priority WHERE (namespace = ? AND pkg_type IS NULL) OR (namespace IS NULL AND pkg_type = ?) OR (namespace = ? AND pkg_type = ?);));

    # bind each var twice to accommodate wacky SQL
    $get_group_priority->execute($ns,$pkg_type,$ns,$pkg_type);
    my ($group_priority) = $get_group_priority->fetchrow_array();
    
    # if we didn't find a priority, default to last group
    $group_priority = 0xFFF1 if (! defined $group_priority);
    
    return $group_priority;
}

=item reprioritize
set the priority of all items in queue based upon priority table
=synopsis
# reorder existing volumes in queue
reprioritize();
# set priority on items just added to queue
reprioritize(1);
=cut
sub reprioritize{
    my $only_new_items = shift;
    my $where_syntax;
    if ($only_new_items){
        # select new items (0xFFFDxx) and not set to last (0xFFFFFF)
        $where_syntax = 'priority > 0xFFFC00 AND priority < 0xFFFFFF';
    }
    else{
        # select existing items
        $where_syntax = 'priority != 0 AND priority < 0xFFFD00';
    }

    my $get_nspkgs = HTFeed::DBTools::get_dbh()->prepare(qq(SELECT DISTINCT namespace, pkg_type FROM queue WHERE $where_syntax;));
    my $update_priority = HTFeed::DBTools::get_dbh()->prepare(qq(UPDATE queue SET priority = (? * 0x100) + (priority & 0xFF) WHERE namespace = ? AND pkg_type = ? AND $where_syntax;));
    
    $get_nspkgs->execute();
    while(my ($ns,$pkg) = $get_nspkgs->fetchrow_array()){
        my $priority = group_priority($ns,$pkg);
        $update_priority->execute($priority,$ns,$pkg);
        
        #print "$ns,$pkg,$priority\n";
    }
    
    return;
}

## Do we need this?
#sub set_group_priorities{
#    
#}

1;

__END__
