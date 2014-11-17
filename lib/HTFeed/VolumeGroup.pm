package HTFeed::VolumeGroup;

use warnings;
use strict;
use Carp;

use HTFeed::Config;
use List::Compare;

sub new {
    my $class = CORE::shift;
    my $self = {
		# affect all volumes
        namespace => undef,
        packagetype => 'ht',
		# hold volumes in various forms
        htids => undef,
        ns_objids => undef,
        objids => undef,
        volumes => undef,
        @_,
    };

    bless $self, $class;
}

sub has_htids {
    my $self = CORE::shift;
    return 1 if ($self->{htids});
    return;
}

sub has_ns_objids {
    my $self = CORE::shift;
    return 1 if ($self->{ns_objids});
    return;
}

sub has_objids {
    my $self = CORE::shift;
    return 1 if ($self->{objids});
    return;
}

sub has_volumes {
    my $self = CORE::shift;
    return 1 if ($self->{volumes});
    return;
}

sub get_htids {
    my $self = CORE::shift;
    return $self->{htids} if ($self->{htids});
    if ($self->{ns_objids}){
        my @htids;
        foreach my $ns_objid (@{$self->{ns_objids}}) {
            push @htids, join(q(.),@{$ns_objid});
        }
        $self->{htids} = \@htids;
        return $self->{htids};
    }
    if ($self->{objids} and $self->{namespace}){
        my @htids;
        my $namespace = $self->{namespace};
        foreach my $objid (@{$self->{objids}}) {
            push @htids, join(q(.),$namespace,$objid);
        }
        $self->{htids} = \@htids;
        return $self->{htids};
    }
    croak 'cannot generate htids';
}

sub get_ns_objids {
    my $self = CORE::shift;
    return $self->{ns_objids} if ($self->{ns_objids});
    if ($self->{htids}){
        my @ns_objids;
        foreach my $htid (@{$self->{htids}}) {
            push @ns_objids, [split(/\./,$htid,2)];
        }
        $self->{ns_objids} = \@ns_objids;
        return $self->{ns_objids};
    }
    if ($self->{objids} and $self->{namespace}){
        my @ns_objids;
        my $namespace = $self->{namespace};
        foreach my $objid (@{$self->{objids}}) {
            push @ns_objids, [$namespace,$objid];
        }
        $self->{ns_objids} = \@ns_objids;
        return $self->{ns_objids};
    }
    croak 'cannot generate ns_objids';
}

# croaks on volume errors
sub get_volumes {
    my $self = CORE::shift;
    return $self->{volumes} if ($self->{volumes});

    my $ns_objids = $self->get_ns_objids();
    my $packagetype = $self->{packagetype};

    my @volumes;
    eval{
        foreach my $ns_objid (@{$ns_objids}) {
            push @volumes, _mk_vol($packagetype,@{$ns_objid});
        }
    };
    croak "Could not instantiate volume: $@" if ($@);

    $self->{volumes} = \@volumes;
    return $self->{volumes};
}

# shifts out a Volume object
# shifts the next one if there is a VOLUME_ERROR
sub shift {
    my $self = CORE::shift;

    # we will return a Volume object if we have one, otherwise we at least need ns_objid pairs
    if(!$self->has_volumes() and !$self->has_ns_objids()) {
        my $ns_objids = $self->get_ns_objids();
    }

    # shift all arrays we have to keep them consistant
    my ($volume,$ns_objid,$objid,$htid);
    $volume = CORE::shift @{$self->{volumes}}
        if ($self->{volumes});
    $ns_objid = CORE::shift @{$self->{ns_objids}}
        if ($self->{ns_objids});
    $objid = CORE::shift @{$self->{objids}}
        if ($self->{objids});
    $htid = CORE::shift @{$self->{htids}}
        if ($self->{htids});

    return $volume
        if ($volume);

    eval{
        $volume = _mk_vol($self->{packagetype}, @{$ns_objid})
            if ($ns_objid);
    };
    if ($@) {
        $htid ||= join '.', @{$nsobjid};
        warn "Error $@ instantiating volume $htid";
        return $self->shift;
    }

    return $volume
        if ($volume);

    return;
}

sub size {
    my $self = CORE::shift;

    return scalar(@{$self->{volumes}})   if ($self->{volumes});
    return scalar(@{$self->{ns_objids}}) if ($self->{ns_objids});
    return scalar(@{$self->{htids}})     if ($self->{htids});
    return scalar(@{$self->{objids}})    if ($self->{objids});

    die 'error finding VolumeGroup size';
}

sub _mk_vol{
    my ($packagetype, $namespace, $id) = @_;
    return HTFeed::Volume->new(
        objid       => $id,
        namespace   => $namespace,
        packagetype => $packagetype,
    );
}

sub intersection {
    my $lc = _get_list_compare_obj(@_);
    my @new_htids = $lc->get_intersection;
    return HTFeed::VolumeGroup->new(htids=>\@new_htids);
}

sub _get_list_compare_obj {
    my $a = CORE::shift;
    my $b = CORE::shift;

    croak 'set operations on VolumeGroups with non matching packagetypes not currectly supported'
        unless ($a->{packagetype} eq $b->{packagetype});

    my $a_htids = $a->get_htids();
    my $b_htids = $b->get_htids();

    return List::Compare->new($a_htids, $b_htids);
}

# $vg->write_id_file($path)
sub write_id_file {
    my $self = CORE::shift;
    my $file_pathname = CORE::shift;

    my $htids = $self->get_htids();

    die "$file_pathname already exists" if (-e $file_pathname);
    open (IDFILE, ">$file_pathname");
    foreach my $htid (@{$htids}) {
        say IDFILE $htid;
    }
    close (IDFILE);
}

1;

__END__

=description

Object to hold a normalized array of volumes with any of several input types.
Also does some basic set operations on multiple groups.

=caveats

Don't use this directly, very rough around the egdes.
Don't create a group with multiple input types.
Internal datatype conversion from volumes to other types is not supported.
Set ops on volumes not supported.

=cut
