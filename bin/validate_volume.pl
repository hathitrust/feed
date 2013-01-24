#!/usr/bin/perl

=description

validate_volume.pl runs a SIP through all stages of preingest transformation, image validation and METS creation.

=cut

use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(set_config);
use HTFeed::RunLite qw(runlite);
use HTFeed::Volume;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use strict;
use warnings;

# autoflush STDOUT
$| = 1;


# report all image errors
set_config(0,'stop_on_error');

my $ignore_errors = 0;
my $clean = 1;
my $one_line = 0; # -1
my $help = 0; # -help,-?

my $dot_packagetype = undef; # -d
my $default_packagetype = undef; # -p
my $default_namespace = undef; # -n

# read flags
GetOptions(
    '1' => \$one_line,
    'help|?' => \$help,
    'dot-packagetype|d=s' => \$dot_packagetype,    
    'pkgtype|p=s' => \$default_packagetype,
    'namespace|n=s' => \$default_namespace,
    "ignore_errors!" => \$ignore_errors, 
    "clean!"         => \$clean,
)  or pod2usage(2);

pod2usage(1) if $help;

# check options
pod2usage(-msg => '-1 and -d flags incompatible', -exitval => 2) if ($one_line and $dot_packagetype);
pod2usage(-msg => '-p and -n exclude -d and -1', -exitval => 2) if (($default_packagetype or $default_namespace) and ($one_line or $dot_packagetype));

if ($one_line){
    $default_packagetype = shift;
    $default_namespace = shift;
}

pod2usage(-msg => 'must specify package type with -p or -d') if not defined $default_packagetype and not defined $dot_packagetype;

my @volumes;

# handle -1 flag (no infile read, get one object form command line)
if ($one_line) {
    my $objid = shift;
    unless( $default_packagetype and $default_namespace and $objid ){
        die 'Must specify namespace, packagetype, and objid when using -1 option';
    }

    push @volumes, HTFeed::Volume->new(packagetype => $default_packagetype, namespace => $default_namespace, objid => $objid);
}
else{
    # handle -d (read infile in dot format)
    if ($dot_packagetype) {
        while (<>) {
            # simplified, lines should match /(.*)\.(.*)/
            $_ =~ /^([^\.\s]*)\.([^\s]*)$/;
            my ($namespace,$objid) = ($1,$2);
            unless( $namespace and $objid ){
                die "Bad syntax near: $_";
            }

            push @volumes, HTFeed::Volume->new(packagetype => $dot_packagetype, namespace => $namespace, objid => $objid);
        }
    }

    # handle default case (read infile in standard format)
    if (! $dot_packagetype) {
        while (<>) {
            next if ($_ =~ /^\s*$/); # skip blank line
            my @words = split;
            my $objid = pop @words;
            my $namespace = (pop @words or $default_namespace);
            my $packagetype = $default_packagetype;
            unless( $packagetype and $namespace and $objid ){
                die "Missing parameter near: $_";
            }

            eval {
                push @volumes, HTFeed::Volume->new(packagetype => $packagetype, namespace => $namespace, objid => $objid);
            };
            if($@) {
                warn($@);
            }
        }
    }
}

my $stage_map = $volumes[0]->get_stage_map();
$stage_map->{metsed} = 'HTFeed::Stage::Done';


runlite(volumegroup => new HTFeed::VolumeGroup(volumes => \@volumes), logger => 'validate_volume.pl', verbose => 1, clean => $clean);
