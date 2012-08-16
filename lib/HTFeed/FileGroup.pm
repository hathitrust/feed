package HTFeed::FileGroup;

use strict;
use warnings;

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

sub get_filenames {
    my $self = shift;
    return $self->{files};
}

sub get_use {
    my $self = shift;
    return $self->{use};
}

sub get_prefix {
    my $self = shift;
    return $self->{prefix};
}

sub get_required {
    my $self = shift;
    return $self->{required};
}

sub get_preservation_level {
    my $self = shift;
    if(defined $self->{preservation_level}) {
        return $self->{preservation_level};
    } else {
        # default: 
        return 1;
    }
}

sub in_structmap {
    my $self = shift;
    return (not defined $self->{structmap} or $self->{structmap})
}


1;

__END__

=head1 HTFeed::FileGroup - Manage Feed file groups

=head1 SYNOPSIS

=head1 DESCRIPTION

Feed uses File Groups to differentiate and process the varying types of files that might be included together in ingest package (eg image, ocr, xml).

=head2 METHODS

=over 4

=item new()

Creates a new file group with the given files. The optional use and prefix
set the use and ID prefix for the file group in the METS file.

new[file1, file2, ...], use => 'use', prefix => 'prefix');

=item get_filenames()

Returns all the files in a file group

=item get_use()

Returns the use for this group of files to set in the METS fileGrp

=item get_prefix()

Returns the prefix for this group of files to set in the METS fileGrp

=item get_required()

Returns whether this filegroup is required to have content.

=item in_structmap()

Returns whether files in this filegroup should be used in the METS structMap.
The default is that files are used in a structMap. Override this by setting
structmap => 0.

=back

INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
