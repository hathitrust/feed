package HDL::Entry::HS_ADMIN;

use warnings;
use strict;
use base qw(HDL::Entry);

sub new {
	my $class = shift;
	my $admin = shift;
	
	my $admin_permissions = shift;
	
	if (defined $admin_permissions){
	    $admin_permissions = flip $admin_permissions;
	}
	else{
	    $admin_permissions = 0x0FF2;
	}

	my $data = _make_data_blob ($admin, $admin_permissions);
	
	return $class->SUPER::new(type => 'HS_ADMIN', data => $data, permissions => [1,1,0,0]);
}

# flips permissions between HDL representation and storage representation
#
# input int should look like 0b 0000 ABCD EFGH IJKL
# output is 0b 0000 LKJI HGFE DCBA
sub _flip{
    my $bits = shift;

    # flip bits in a string
    my $reversed_bit_string = scalar reverse sprintf("%012b",$bits);
    # make sure the permissions have 12 or fewer bits
    die "Invalid permission bits" unless (length($reversed_bit_string) eq 12);

    my $flipped_bits;
    eval "\$flipped_bits = 0b$reversed_bit_string;";
    
    return $flipped_bits;
}

# _make_data_blob(0.NA/1234, 0x0FF2)
sub _make_data_blob{
    my $admin_handle = shift;
    my $perms = shift;
    
    my $zero = 0x0000;
    my $length = length $admin_handle;
    my $index = 300;
    
    my $bin = pack ("n n n A$length n n n", $perms, $zero, $length, $admin_handle, $zero, $index, $zero);
    
    return $bin;
}

# returns an array ref of the data blob's unpacked contents
sub _extract_data_blob{
    my $self = shift;
    my $bin = $self->{data};
    
    my ($perms, $zero, $length, $text, $index);
    ($perms, $zero, $length) = unpack ("n n n", $bin);
    ($perms, $zero, $length, $text, $zero, $index, $zero) = unpack ("n n n A$length n n n", $bin);
    
    # return the name of the admin handle and the associated permissions
    # $index and $length could also be returned here, but they aren't very interesting
    return [$text, $perms];
}

# returns admin handle name followed by permissions in flipped (i.e. handle form) hex
sub to_string{
    my $self = shift;

    my $data = $self->_extract_data_blob();
    my $name = shift @$data;
    my $perms = _flip shift @$data;
    return sprintf ('%s 0x%X', $name, $perms);
}

# returns data unpacked into a hex string, and formatted for SQL
sub get_SQL_ready_data{
    my $self = shift;
    my $hex = $self->get_hex_string();
    return "X'$hex'";
}

1;

__END__
