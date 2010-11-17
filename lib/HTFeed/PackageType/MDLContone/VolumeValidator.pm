#!/usr/bin/perl

package HTFeed::PackageType::MDLContone::VolumeValidator;

use base qw(HTFeed::VolumeValidator);

use strict;


=item _validate_filegroups

For MDL contones, ensure that image has exactly one item.

=cut
sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    $self->{stages}{validate_filegroups} = \&_validate_filegroups;
    $self->{stages}{validate_consistency} =  \&_validate_consistency;

    return $self;

}

sub _validate_filegroups {
    my $self   = shift;
    my $volume = $self->{volume};
    $self->SUPER::_validate_filegroups();

    my $image_filegroup          = $volume->get_file_groups()->{'image'};
    my $filecount = scalar(@{$image_filegroup->get_filenames()});
    if($filecount != 1) {
	    $self->set_error("BadFilegroup", filegroup => $image_filegroup, detail => 'Expected exactly one file');
    }

    return;
}

# No-op for MDL contones, since there are no sequence numbers..
sub _validate_consistency {
    my $self   = shift;
    my $volume = $self->{volume};

    return;

}

1;
