package HTFeed::Storage::LocalPairtree;

use strict;

use HTFeed::Storage;
use base qw(HTFeed::Storage);

use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);
use HTFeed::VolumeValidator;
use Log::Log4perl qw(get_logger);
use URI::Escape;

sub object_path {
    my $self = shift;

    $self->{object_path} ||= $self->SUPER::object_path('obj_dir');
}

sub stage_path {
    my $self = shift;

    $self->SUPER::stage_path('obj_dir');
}

sub existing_object_tmpdir {
    my $self = shift;

    my $objdir = $self->follow_existing_link;

    if ($objdir =~ qr(^(.*)/$self->{namespace}/pairtree_root/.*)) {
        get_logger()->trace("Using existing object dir $objdir; staging to $1/.tmp");
        return $self->stage_path_from_base($1);
    } else {
        die("Can't determine storage root from existing storage $objdir");
    }
}

sub move {
    my $self = shift;

    $self->move_existing_aside if $self->existing_object;

    $self->SUPER::move;
}

sub rollback {
    my $self = shift;

    return unless $self->{can_roll_back};

    my $zipfile  = $self->zip_obj_path;
    my $metsfile = $self->mets_obj_path;

    get_logger()->warn("Rolling back to previous version");

    $self->safe_system('mv', '-f', "$metsfile.old", $metsfile) if -e "$metsfile.old";
    $self->safe_system('mv', '-f', "$zipfile.old", $zipfile)   if -e "$zipfile.old";

    $self->SUPER::rollback;
}

sub cleanup {
    my $self = shift;

    my $zipfile  = $self->zip_obj_path;
    my $metsfile = $self->mets_obj_path;

    $self->safe_system('rm', '-f', "$metsfile.old") if -e "$metsfile.old";
    $self->safe_system('rm', '-f', "$zipfile.old")  if -e "$zipfile.old";

    $self->SUPER::cleanup;
}

sub move_existing_aside {
    my $self = shift;

    my $zipfile  = $self->zip_obj_path;
    my $metsfile = $self->mets_obj_path;

    if (
        $self->safe_system('mv', $metsfile, "$metsfile.old") &&
        $self->safe_system('mv', $zipfile, "$zipfile.old")
    ) {
        $self->{can_roll_back} = 1;
    } else {
        die("$self->{namespace}.$self->{id}: Can't move aside existing object. Repository is likely inconsistent; manual intervention required");
    }
}

sub existing_object {
    my $self = shift;

    return -f $self->zip_obj_path && -f $self->mets_obj_path;
}

sub make_object_path {
    my $self = shift;

    if (! -d $self->object_path) {
        $self->safe_make_path($self->object_path);
    }

    return 1;
}

sub record_audit {
  get_logger()->warn("LocalPairtree for dev/testing purposes only; not recording audit");
  return 1;
}

1;
