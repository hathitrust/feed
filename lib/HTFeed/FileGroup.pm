package HTFeed::FileGroup;

=item new([file1, file2, ...], use => 'use', prefix => 'prefix')

Creates a new file group with the given files. The optional use and prefix
set the use and ID prefix for the file group in the METS file.

=cut

sub new {
    my $class = shift;
    my $files = shift;

    my $self = {
	files => $files,
	use => undef,
	prefix => undef,
	@_
    };

    bless($self,$class);
    return $self;
}

=item get_files()

Returns all the files in this file group

=cut

sub get_filenames {
    my $self = shift;
    return $self->{files};
}

=item get_use()

Returns the use for this group of files to set in the METS fileGrp

=cut

sub get_use {
    return $self->{use};
}

=item get_prefix()

Returns the prefix for this group of files to set in the METS fileGrp

=cut

sub get_prefix {
    return $self->{prefix};
}


1;

__END__;
