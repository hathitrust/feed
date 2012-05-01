package HTFeed::Stage::JHOVE_Runner;

use warnings;
use strict;
use Log::Log4perl qw(get_logger);
use XML::LibXML;
use Carp;
use HTFeed::XMLNamespaces qw(register_namespaces);
use HTFeed::Config qw(get_config);

use base qw(HTFeed::Stage);

=head1 NAME

HTFeed::Stage::JHOVE_Runner

=head1 DESCRIPTION

Abstract class for stages (VolumeValidator,
ImageRemediate, etc) that may need to
run  JHOVE on a set of files.

=cut

=item run_jhove()

runs JHOVE in the given directory on the given files and calls the given
callback once per file with a parsed XML document with the JHOVE output for
that file.

$self->run_jhove($volume,$dir,$files,$callback)

where $callback is a function accepting three parameters: the volume, the
filename, and the parsed XML JHOVE output.

=cut

sub run_jhove {
    my $self   = shift;

    # get files
    my $volume = shift;
    my $dir   = shift;
    my $files = shift;
    my $callback = shift;
    my $add_args = (shift or '');

    # make sure we have >0 files
    if ( !@$files ) {
        $self->set_error(
            "BadFile",
            file   => "all",
            detail => "Zero files found to validate"
        );
        return;
    }

    # prepend directory to each file to validate
    my $files_for_cmd = join( "' '", map { "$_" } @$files );
    my $jhove_path = get_config('jhove');
    my $jhove_conf = get_config('jhoveconf');
    my $jhove_cmd = "cd '$dir'; $jhove_path -h XML -c $jhove_conf $add_args '$files_for_cmd'";
    get_logger()->trace("jhove cmd $jhove_cmd");

    # make a hash of expected files
    my %files_left_to_process = map { $_ => 1 } @$files;

    # open pipe to jhove
    my $pipe = IO::Pipe->new();
    $pipe->reader($jhove_cmd);

    # get the header
    my $control_line = <$pipe>;
    my $head         = <$pipe>;
    my $date_line    = <$pipe>;
    my $tail         = '</jhove>';

    # start looking for repInfo block
    DOC_READER: while (<$pipe>) {
        if (m|^\s*<repInfo.+>$|) {

            # save the first line when we find it
            my $xml_block = "$_";

            # get the rest of the lines for this repInfo block
            BLOCK_READER: while (<$pipe>) {

                # save more lines until we get to </repInfo>
                $xml_block .= $_;
                last BLOCK_READER if m|^\s*</repInfo>$|;
            }

            # get file name from xml_block
            $xml_block =~ m{^\s*<repInfo\suri=".*/(.*)"|^\s*<repInfo\suri="(.*)"};
            my $file;
            $file = $1 or $file = $2;

            # remove file from our list
            delete $files_left_to_process{$file};

            # validate file
            {

                # put the headers on xml_block, parse it as a doc
                $xml_block =
                $control_line . $head . $date_line . $xml_block . $tail;

                #                print $xml_block;
                my $parser = XML::LibXML->new();
                my $node = $parser->parse_string($xml_block);
                &$callback($volume,$file,$node)
            }

        }
        elsif (m|^\s*</jhove>$|) {
            last DOC_READER;
        }
        elsif (m|<app>|) {

            # jhove was run on zero files, that should never happen
            croak "jhove was run on zero files";
        }
        else {

            # this should never happen
            die "could not parse jhove output";
        }
    }

    if ( keys %files_left_to_process ) {

        # this should never happen
        die "missing a block in jhove output";
    }

    return;
}

1;

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
