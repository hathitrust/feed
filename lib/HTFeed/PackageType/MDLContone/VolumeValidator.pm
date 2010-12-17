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

    $self->{stages}{validate_filegroups_nonempty} = \&_validate_filegroups_nonempty;
    $self->{stages}{validate_consistency} =  \&_validate_consistency;

    return $self;

}

sub _validate_filegroups_nonempty {
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

1;
