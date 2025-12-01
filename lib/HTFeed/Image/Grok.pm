package HTFeed::Image::Grok;

use strict;
use warnings;

use HTFeed::Config qw(get_config);
use HTFeed::Image::Shared;

# This package contains all of the system calls to grok.
# They used to be buried deep in ImageRemediate, hard to test.
#
# All subs require an infile path and an outfile path.

sub compress {
    my $infile  = shift;
    my $outfile = shift;
    my %args    = @_;

    # Copy args from %args to %ok_args when key is in @ok_keys.
    #
    # The only arg we currently allow is -n ("levels"),
    # which has the default value 5.
    # See HTFeed::Stage::ImageRemediate::convert_tiff_to_jpeg2000
    my %ok_args = ();
    my @ok_keys = qw(-n);
    foreach my $k (@ok_keys) {
        if (exists $args{$k}) {
            $ok_args{$k} = $args{$k};
        }
    }
    # Default arg values:
    $ok_args{-n} ||= 5;

    my $base_cmd = get_config('grk_compress');

    my $validate = {
        infile   => $infile,
        outfile  => $outfile,
        base_cmd => $base_cmd
    };

    HTFeed::Image::Shared::check_set($validate) || return 0;

    my $full_cmd = join(
        " ",
        "$base_cmd",
        each %ok_args,
        "-i '$infile'",
        "-o '$outfile'",
        "-p RLCP", # the rest of these args never change,
        "-S",    # so for now leave them hard-coded
        "-E",
        "-M 62",
        "-I",
        "-q 32",
        "> /dev/null 2>&1"
    );

    my $sys_ret_val = system($full_cmd);

    return !$sys_ret_val;
}

sub decompress {
    my $infile  = shift;
    my $outfile = shift;

    my $base_cmd = get_config('grk_decompress');

    my $validate = {
        infile   => $infile,
        outfile  => $outfile,
        base_cmd => $base_cmd
    };
    HTFeed::Image::Shared::check_set($validate) || return 0;

    my $full_cmd = join(
        " ",
        "$base_cmd",
        "-i '$infile'",
        "-o '$outfile'",
        "> /dev/null 2>&1"
    );
    my $sys_ret_val = system($full_cmd);

    return !$sys_ret_val;
}

1;
