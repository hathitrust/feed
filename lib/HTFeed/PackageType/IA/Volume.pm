package HTFeed::PackageType::IA::Volume;

use warnings;
use strict;
use base qw(HTFeed::Volume);
use DBI;
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
    
    ## TODO: replace this DB boilerplate with DB library, after merging with trunk
    my $datasource = get_config('database'=>'datasource');
    my $user = get_config('database'=>'username');
    my $passwd = get_config('database'=>'password');

    my $dbh = DBI->connect($datasource, $user, $passwd);
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
