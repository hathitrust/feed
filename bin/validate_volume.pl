#!/usr/bin/perl


use FindBin;
use lib "$FindBin::Bin/../lib";
use HTFeed::Log {root_logger => 'INFO, screen'};
use HTFeed::Config qw(set_config);
use HTFeed::RunLite qw(runlite);
use HTFeed::Volume;
use HTFeed::VolumeValidator;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use HTFeed::Stage::Done;
use strict;
use warnings;

# autoflush STDOUT
$| = 1;


# report all image errors
set_config(0,'stop_on_error');

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

local *HTFeed::Volume::get_sources = sub {
  return ( 'ht_test','ht_test','ht_test' );
};

# don't validate digitizer -- will fail against faked up sources
local *HTFeed::VolumeValidator::_validate_digitizer = sub {
  return 1;
};

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

__END__

=head1 NAME

    validate_volume.pl - validate volumes by running all stages through METS generation

=head1 SYNOPSIS

validate_volume.pl [-p packagetype [-n namespace]] [infile]

validate_volume.pl -d packagetype [infile]

validate_volume.pl -1 packagetype namespace objid

    INPUT OPTIONS

      -d dot format infile - follow with packagetype
          all lines of infile are expected to be of the form namespace.objid.

      -1 only one volume, read from command line and not infile

      -p,-n - specify packagetype, namespace respectivly.
        incompatible with -d, -1
    
    GENERAL OPTIONS

      --clean - clean up temporary files directories after validation (default)
      --no-clean - leave temporary files and directories in place after validation 

    INFILE - input read fron last arg on command line or stdin
    
    standard infile contains rows like this:
        [[packagetype] namespace] objid
    
    dot-style (-d) infile rows:
        namespace.objid
=cut

