package HTFeed::Image::Magick;

use strict;
use warnings;

use HTFeed::Config qw(get_config);
use HTFeed::Image::Shared;

# This package contains all of the systemcalls to magick (imagemagick).

# E.g. HTFeed::Image::Magick::compress("a", "b", '-compress' => 'Group4');
sub compress {
    my $infile  = shift;
    my $outfile = shift;
    my %args    = @_;

    # Copy args from %args to %ok_args when key is in @ok_keys.
    my %ok_args = ();
    my @ok_keys = qw(-compress -depth -type);
    foreach my $k (@ok_keys) {
        if (exists $args{$k}) {
            $ok_args{$k} = $args{$k};
        }
    }

    my $base_cmd = get_config('imagemagick');
    my $validate = {
        infile    => $infile,
        outfile   => $outfile,
        base_cmd  => $base_cmd,
        -compress => $args{-compress}
    };
    HTFeed::Image::Shared::check_set($validate) || return 0;

    my $full_cmd = join(
        " ",
        "$base_cmd",
        each %ok_args,
        "'$infile'",
        "-strip",
        "'$outfile'"
    );
    my $sys_ret_val = system($full_cmd);

    return !$sys_ret_val;
}

1;
