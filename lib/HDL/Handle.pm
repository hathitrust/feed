package HDL::Handle;

use warnings;
use strict;
use Carp;

use HDL::Entry;

sub new {
	my $class = shift;
	
	my $params = 
		{   
		    name => undef,
			url	=> undef,
			email => undef,
			root_admin => undef,
			local_admin => undef,
			@_,
		};
	
	unless(defined $params->{name} and defined $params->{root_admin}){
	    croak '__PACKAGE__: Missing required parameters';
    }
    
    my $name = uc $params->{name};
    my $self = {name => $name, entries => {}};
    
	if (defined $params->{url}){
		$self->{entries}->{1} = HDL::Entry::URL->new($params->{url});		
	}
	if (defined $params->{email}){
		$self->{entries}->{2} = HDL::Entry::EMAIL->new($params->{email});
	}
	if (defined $params->{root_admin}){
		$self->{entries}->{100} = HDL::Entry::HS_ADMIN->new($params->{root_admin});
	}
	if (defined $params->{local_admin}){
		$self->{entries}->{101} = HDL::Entry::HS_ADMIN->new($params->{local_admin});
	}
	
	my $entry_hash_size = scalar keys %{ $self->{entries} };
	my $required_entry_hash_size = 2 + defined $params->{local_admin};
	
	if ($entry_hash_size < $required_entry_hash_size){
	    croak '__PACKAGE__: Cannot create a handle with no data';
	}
	
	bless $self, $class;
	return $self;
}

# returns an SQL statment to create the new handle
sub to_SQL{
    my $self = shift;
    my $name = $self->{name};
    my $entries = $self->{entries};
    
    my $timestamp = time;
    
    my $sql = 'INSERT INTO `handles` '
      .'(`handle`,`idx`,`type`,`data`,`ttl_type`,`ttl`,`timestamp`,`refs`,`admin_read`,`admin_write`,`pub_read`,`pub_write`) '
      .'VALUES ';
    
    foreach my $key (sort {$a <=> $b} keys %{ $entries }){
        $sql .= $entries->{$key}->to_SQL_row($name,$key,$timestamp);
        $sql .= "\n";
    }
    
    return $sql;
}

1;

__END__
