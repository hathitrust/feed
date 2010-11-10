package HDL::Entry;

use warnings;
use strict;

require HDL::Entry::HS_ADMIN;
require HDL::Entry::URL;
require HDL::Entry::EMAIL;

sub new {
	my $class = shift;
	my $self =
		{	
			type => undef,
			data => undef,
			permissions => [1,1,1,0],
			ttl_type => 0,
			ttl => 86400,
			@_,
		};
	bless $self, $class;
	return $self;
}

sub to_string {
    my $self = shift;
    return $self->{data};
}

# this is just for testing so we can bypass the override constructors
sub new2{
    my $class = shift;
	my $self =
		{	
			type => undef,
			data => undef,
			permissions => [1,1,1,0],
			ttl_type => 0,
			ttl => 86400,
			@_,
		};
	bless $self, $class;
	return $self;
}

# returns SQL syntax for one row
# this is useless by its self, it is meant to be wrapped my HDL::Handle
# $entry->to_SQL_row($handle_name,$index,$timestamp)
sub to_SQL_row {
    my $self = shift;
    my ($handle_name,$index,$timestamp) = @_;
    my $type = $self->{type};
    my $data = $self->get_SQL_ready_data();
    my $ttl_type = $self->{ttl_type};
    my $ttl = $self->{ttl};
    my $perms = $self->{permissions};
    
    return "('$handle_name','$index','$type',$data,'$ttl_type','$ttl','$timestamp','','" . join('\',\'', @$perms) . '\')';
}

# returns the SQL syntax for the data field
# this is trivial, but it needs to be here so we can override it in HDL::Entry::HS_ADMIN
sub get_SQL_ready_data{
    my $self = shift;
    my $data = $self->{data};
    return "'$data'";
}

# returns data represented in hex
sub get_hex_string{
    my $self = shift;
    my $bin = $self->{data};
    
    my ($hex) = unpack( 'H*', $bin );
    return $hex;
}

1;

__END__
