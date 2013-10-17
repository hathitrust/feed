#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTFeed::Stage::ImageRemediate;
use HTFeed::TestVolume;
use Getopt::Long qw(:config no_ignore_case);
use HTFeed::Log { root_logger => 'INFO, screen' };
use POSIX qw(strftime);
use Carp;
use Pod::Usage;
use File::Basename qw(basename);

use warnings;
use strict;

my $objid = undef;
my $artist = undef;
my $scanner_make = undef;
my $scanner_model = undef;
my $volume_capture_date = undef;
my $resolution = undef;
my $outdir = undef;

GetOptions(
    'outdir|d=s' => \$outdir,
    'objid|o=s' => \$objid,
    'artist|a=s' => \$artist,
    'make=s' => \$scanner_make,
    'model=s' => \$scanner_model,
    'capture-date|c=s' => \$volume_capture_date,
    'resolution|r=s' => \$resolution
)  or pod2usage(2);

pod2usage(2) unless defined $objid and defined $artist;

# make a fake volume for the image remediator
my $remediator = new HTFeed::Stage::ImageRemediate(volume => new HTFeed::TestVolume(namespace => 'namespace', packagetype => 'pkgtype'));

# try to make output directory
die("$outdir is not a directory\n") if -e $outdir and ! -d $outdir;
system("mkdir -p '$outdir'") unless -d $outdir;
die("Failed to make $outdir\n") unless -d $outdir;

foreach my $file (@ARGV) {

    my $basename = basename($file);

    my $outfile = "$outdir/$basename";

    die("$outfile exists, not overwriting") if -e $outfile;

    # reset remediator;
    undef $remediator->{newFields};
    undef $remediator->{oldFields};

    my $capture_date = undef;
    $capture_date = $volume_capture_date 
    if defined $volume_capture_date;

    # fall back to file timestamp if not specified
    $capture_date = strftime("%Y:%m:%d %H:%M:%S+00:00",gmtime((stat("$file"))[9])) 
    if not defined $capture_date;

    my $set_if_undefined = {
        'XMP-dc:source'   => "$objid/$basename",
        'XMP-tiff:Artist' => $artist,
        'XMP-tiff:DateTime' => $capture_date,
    };

    $set_if_undefined->{'XMP-tiff:Make'} = $scanner_make if defined $scanner_make;
    $set_if_undefined->{'XMP-tiff:Model'} = $scanner_model if defined $scanner_model;

    # will try to get from JPEG2000 headers
    $set_if_undefined->{'Resolution'} = $resolution if defined $resolution;

    $remediator->remediate_image($file,"$outfile",undef,$set_if_undefined);

    print "Fixed $file\n";

}

__END__

=head1 NAME

    xmpize_jp2.pl - add XMP to JPEG2000 images

=head1 SYNOPSIS

    xmpize_jp2.pl -d OUTDIR -o OBJID -a ARTIST [-c VOLUME_DATE] [-r RESOLUTION] 
                  [--make MAKE --model MODEL]  00000001.jp2 00000002.jp2 ...

    OPTIONS

    -d | --outdir - directory to write remediated images to (required)

    -o | --objid - volume identifier (required)

    -a | --artist - scanning artist (who pushed the button to scan) (required)

    -c | --capture-date - date/time the volume was scanned (optional; falls back to file timestamp if not given)

    -r - resolution (in dots per inch) the volume was scanned. Uses value from JPEG2000 header if present (required if missing from JPEG2000 header)

    --make - Scanner make (optional)

    --model - Scanner model (optional)

=cut

