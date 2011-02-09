package HTFeed::StagingSetup;

use warnings;
use strict;

use File::Path qw(make_path remove_tree);

use HTFeed::Config qw(get_config);

# delete all staging dirs
sub _wipe_dirs{
    foreach my $dir (@{$_[0]}){
        remove_tree $dir;
    }
}

# create all staging dirs
sub _make_dirs{
    foreach my $dir (@{$_[0]}){
        make_path $dir;
    }
}

# list staging dirs
sub _get_dirs{
    # this is inefficient, but memoizing here would be brittle
    # in special cases (i.e. set_config has been used)
    return [get_config('staging'=>'ingest'),
            get_config('staging'=>'zip'),
            get_config('staging'=>'preingest'),
            get_config('staging'=>'disk'=>'ingest'),
            get_config('staging'=>'disk'=>'preingest'),
    ];
}

# delete all staging dirs if $clean, and make sure they all exist
# make_stage($clean)
sub make_stage{
    my $clean = shift;
    my $dirs = _get_dirs();
    _wipe_dirs($dirs) if $clean;
    _make_dirs($dirs);
    return;
}

# delete all staging dirs
# clear_stage()
sub clear_stage{
    my $dirs = _get_dirs();
    _wipe_dirs($dirs);
    return;
}

1;

__END__

=Synopsis
use HTFeed::Setup;
HTFeed::StagingSetup::make_stage();
HTFeed::StagingSetup::clear_stage();
=Description
creates all staging diectories on BEGIN, unlinks them on END
=cut
