package HTFeed::DBTools::Priority;

=description
    Queries relating to prioritization
    
=explanation of priority field
    priority is a 26 bit int
    lowest number is first in the queue (after priority we order on insert date)
    
    0 = first
    
    NL BBBB BBBB GGGG GGGG SSSS
    
    N = new
    L = last
    B = bin
    S = Sub group priority (1-3)
=cut

use warnings;
use strict;

use Readonly;

# very first/last
Readonly::Scalar my $FIRST      => 0;
Readonly::Scalar my $LAST       => 0x100000;
# masks
Readonly::Scalar my $SUBG_MASK  => 0xF;
Readonly::Scalar my $GROUP_MASK => 0xFF0;
Readonly::Scalar my $BIN_MASK   => 0xFF000;
Readonly::Scalar my $NEW_MASK   => 0x200000;
# offsets
Readonly::Scalar my $GROUP_OFF  => 0x10;
Readonly::Scalar my $BIN_OFF    => 0x1000;
# max/min within group/bin
Readonly::Scalar my $MAX        => 0xFF;
Readonly::Scalar my $MIN        => 0x0;

use Carp;
use Switch;
use base qw(HTFeed::DBTools);

our @EXPORT_OK = qw(reprioritize initial_priority set_item_priority rebin);

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

    my $priority_modifier = shift;
    $priority_modifier = 'default' if not defined $priority_modifier;


    my $priority = 0;
    switch ($priority_modifier){
        case "first"        { $priority = $FIRST }
        case "last"         { $priority = $LAST }
        case "group_first"  { $priority = group_priority($ns,$pkg_type) * $GROUP_OFF + 0x1 }
        case "group_last"   { $priority = group_priority($ns,$pkg_type) * $GROUP_OFF + 0x3 }
        else                { $priority = group_priority($ns,$pkg_type) * $GROUP_OFF + 0x2 }
    }

    my $sth = HTFeed::DBTools::get_dbh()->prepare(qq(UPDATE queue SET priority = (priority & $BIN_MASK) + ? WHERE namespace = ? AND id = ?;));

    $sth->execute($priority,$ns,$id);

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
    $group_priority = $MAX if (! defined $group_priority);

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
        # select new items
        $where_syntax = "priority >= $NEW_MASK";
    }
    else{
        # select existing items, that aren't set to first or last
        $where_syntax = "priority != 0 AND priority < $LAST";
    }

    my $get_nspkgs = HTFeed::DBTools::get_dbh()->prepare(qq(SELECT DISTINCT namespace, pkg_type FROM queue WHERE $where_syntax;));
    my $mask = $BIN_MASK + $SUBG_MASK;
    my $update_priority = HTFeed::DBTools::get_dbh()->prepare(qq(UPDATE queue SET priority = (? * $GROUP_OFF) + (priority & $mask) WHERE namespace = ? AND pkg_type = ? AND $where_syntax;));

    $get_nspkgs->execute();
    while(my ($ns,$pkg) = $get_nspkgs->fetchrow_array()){
        my $priority = group_priority($ns,$pkg);
        $update_priority->execute($priority,$ns,$pkg);

        #print "$ns,$pkg,$priority\n";
    }

    return;
}

=item initial_priority
returns the initial priority the Queue.pm should set on an item before running reprioritize()
=synopsis
initial_priority();
initial_priority($modifier);
=cut
sub initial_priority{
    my $volume = shift;
    my $priority_modifier = shift;
    $priority_modifier = 'default' if not defined $priority_modifier;

    

    # default bin is 1
    my $bin = 1;

    my $priority;

    switch ($priority_modifier){
        # first and last have no group, so skip the flag
        case "first"        { $priority = $FIRST }
        case "last"         { $priority = $LAST }
        # set priority with 'new' flag (from $NEW_MASK) to set group later
        case "group_first"  { $priority = $NEW_MASK + $bin * $BIN_OFF + 0x1 }
        case "group_last"   { $priority = $NEW_MASK + $bin * $BIN_OFF + 0x3 }
        else                { $priority = $NEW_MASK + $bin * $BIN_OFF + 0x2 }
    }

    return $priority;
}

=item rebin
the use of the bin field has still not been fully fleshed out
for now, this will put item into bin 2 by default

any future default behavior will always to be to demote (i.e. increase) the bin an some way
=synopsis
rebin($volume); # demote item
rebin($volume[,$bin]); # place item in bin $bin (1-0xFF)
=cut
sub rebin{
    my $volume = shift;
    my $bin = (shift or 2);
    die "$bin is an invalid bin, bin must be between 1 and $MAX"
        unless (defined $bin and $bin > 0 and $bin <= $MAX);

    my $ns = $volume->get_namespace();
    my $id = $volume->get_objid();

    # clear bin, set bin, don't touch it if priority is FIRST or LAST
    my $sth = HTFeed::DBTools::get_dbh()->prepare(qq(UPDATE queue SET priority = (priority & ~$BIN_MASK) + ? WHERE namespace = ? AND id = ? AND priority != $FIRST AND priority < $LAST;));

    $sth->execute($bin*$BIN_OFF,$ns,$id);
}

1;

__END__
