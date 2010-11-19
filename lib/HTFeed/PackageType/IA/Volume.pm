package HTFeed::PackageType::IA::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use HTFeed::DBTools;
use HTFeed::Config qw(get_config);

sub get_ia_id{
    my $self = shift;
    
    my $ia_id = $self->{ia_id};
    # return it if we have it
    if ($ia_id){
        return $ia_id;
    }
    
    # else get it and memoize
    my $arkid = $self->get_objid();
    
    my $db = new HTFeed::DBTools;
    my $dbh = $db->get_dbh();
    my $sth = $dbh->prepare("select ia_id from ia_arkid where arkid = ?");
    $sth->execute($arkid);
    
    my $results = $sth->fetchrow_arrayref();
    
    #TODO make this work if db result is null
    $ia_id = $results->[0];
    
    $self->{ia_id} = $ia_id;
    return $ia_id;
}

1;

__END__
