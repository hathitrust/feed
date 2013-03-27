package Shell::Comm;

use warnings;
use strict;

#use v5.10;
use File::Temp qw(tempfile);
use IO::Pipe;
use Carp;

use base qw(Exporter);
our @EXPORT = qw(comm);

our $DIR;
our $TEMPLATE;
our $SUFFIX;

=item comm

=synopsis

comm(\@a,\@b,'common'); # list common items
comm(\@a,\@b,'a'); # list items unique to @a
comm(\@a,\@b,'b'); # list items unique to @b

=cut
sub comm {
    my ($a,$b,$arg) = @_;
    my $flag;
    $flag = '-12' if $arg eq 'common' or $arg eq '12';
    $flag = '-23' if $arg eq 'a' or $arg eq '23';
    $flag = '-13' if $arg eq 'b' or $arg eq '13';
    croak "comm: invalid arg - $arg" if not defined $flag;

    my @a = sort @{$a};
    my @b = sort @{$b};
    my $a_file = File::Temp->new(DIR => $DIR);
    my $a_filename = $a_file->filename;
    print $a_file join "\n", @a;
    $a_file->close();
    my $b_file = File::Temp->new(DIR => $DIR);
    my $b_filename = $b_file->filename;
    print $b_file join "\n", @b;
    $b_file->close();
    
    my $cmd = "comm $flag $a_filename $b_filename";
    
    my $pipe = IO::Pipe->new();
    $pipe->reader($cmd);

    my @results;
    while (<$pipe>) {
        chomp;
        push @results, $_;
    }

    print STDERR "$a_filename\n$b_filename\n";

    return \@results;
}

1;

#TEMPLATE => 'shell-comm-XXXXXXXXXX'
