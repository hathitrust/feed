package HTFeed::Volume;

use warnings;
use strict;
use Log::Log4perl qw(get_logger);
use HTFeed::Namespaces qw(register_namespaces);
use XML::LibXML;

our $logger = get_logger(__PACKAGE__);

sub new {
    my $class = shift;

    my $self = {
        objid     => undef,
        namespace => undef,
        packagetype => undef,
        @_,

        #		files			=> [],
        #		dir				=> undef,
        #		mets_name		=> undef,
        #		mets_xml		=> undef,
    };

    # TODO: validate barcode when created (need namespace configuration)

    $self->{groove_book} =
      GROOVE::Book->new( $self->{objid}, $self->{namespace},
        $self->{packagetype} );

    bless( $self, $class );
    return $self;
}

=item get_identifier

Returns the full identifier (namespace.objid) for the volume

=cut

sub get_identifier {
    my $self = shift;
    return $self->get_namespace() . q{.} . $self->get_objid();

}

=item get_objid

Returns the ID (without namespace) of the volume.

=cut

sub get_objid {
    my $self = shift;
    return $self->{objid};
}

=item get_namespace

Returns the namespace of the volume

=cut

sub get_namespace {
    my $self = shift;
    return $self->{namespace};
}

=item get_file_groups 

Returns a hash of lists containing the logical groups of files within the volume.

For example:

{ 
  ocr => [0001.txt, 0002.txt, ...]
  image => [0001.tif, 0002.jp2, ...]
}

=cut

sub get_file_groups {
    my $self = shift;

    my $book = $self->{groove_book};

    my $filegroups = {};
    $filegroups->{image} = [ $book->get_all_images() ];
    $filegroups->{ocr}   = [ $book->get_all_ocr() ];
    $filegroups->{hocr} = [ $book->get_all_hocr() ] if $book->hocr_files_used();

    return $filegroups;
}

=item get_all_directory_files

Returns a list of all files in the staging directory for the volume's AIP

=cut

sub get_all_directory_files {
    my $self = shift;

    return $self->{groove_book}->get_all_files();
}

=item get_staging_directory

Returns the staging directory for the volume's AIP

=cut

sub get_staging_directory {
    my $self = shift;
    return $self->{groove_book}->get_path();
}

=item get_all_content_files

Returns a list of all files that will be validated with JHOVE

=cut

sub get_all_content_files {
    my $self = shift;
    my $book = $self->{groove_book};

    return ( $book->get_all_images(), $book->get_all_ocr(),
        $book->get_all_hocr() );
}

=item get_valid_file_pattern

Returns a regular expression that matches files that may appear in this volume's AIP

=cut

sub get_valid_file_pattern {
    die("Need to implement namespace/pkgtype config");
}

=item validate_barcode

Returns true if the volume's barcode is valid for the volume's namespace and false otherwise.

=cut

sub validate_barcode {
    die("Need to implement namespace config");
}

=item allow_sequence_gaps

Returns true if the numeric naming sequence of files for images, etc. can have gaps in it

=cut

sub allow_sequence_gaps {
    die("Need to implement namespace/pkgtype config");
}

=item get_checksums

Returns a hash of precomputed checksums for files in the package's AIP where
the keys are the filenames and the values are the MD5 checksums.

=cut

sub get_checksums {
    my $self = shift;

    if ( !defined $self->{checksums} ) {
        my $checksums = {};

        my $checksum_file = $self->{groove_book}->get_checksum_file();
        if ( defined $checksum_file ) {
            my $checksum_fh;
            open( $checksum_fh, "<", $checksum_file )
              or croak("Can't open $checksum_file: $!");
            while ( my $line = <$checksum_fh> ) {
                chomp $line;
                my ( $filename, $checksum ) = split( /\s+/, $line );
                $checksums->{$filename} = $checksum;
            }
            close($checksum_fh);
        }
        else {

            # try to extract from source METS
            my $xpc = $self->get_source_mets_xpc();
            foreach my $node ( $xpc->find_nodes('//mets:file') ) {
                my $checksum = $xpc->find_value( './@CHECKSUM', $node );
                my $filename =
                  $xpc->find_value( './mets:FLocat/@xlink:href', $node );
                $checksums->{$filename} = $checksum;
            }
        }
        $self->{checksums} = $checksums;
    }

    return $self->{checksums};
}

=item get_checksum_file

Returns the name of the file containing the checksums. Useful since that file won't have
a checksum computed for it.

=cut

sub get_checksum_file {
    my $self          = shift;
    my $checksum_file = $self->{groove_book}->get_checksum_file();
    $checksum_file = $self->{groove_book}->get_source_mets_file()
      if not defined $checksum_file;
    return $checksum_file;
}

=item get_source_mets_file

Returns the name of the source METS file

=cut

sub get_source_mets_file {
    my $self = shift;
    return $self->{groove_book}->get_source_mets_file();
}

=item get_source_mets_xpc

Returns an XML::LibXML::XPathContext with the following namespace set:

and the context node positioned at the document root of the source METS.

=cut

sub get_source_mets_xpc {
    my $self = shift;

    my $mets = $self->get_source_mets_file();
    my $xpc;

    eval {
        my $parser = XML::LibXML->new();
        my $doc    = $parser->parse_file($mets);
        $xpc = XML::LibXML::XPathContext->new($doc);
        register_namespaces($xpc);
    };

    if ($@) {
        croak("-ERR- Could not read XML file $mets: $@");
    }
    return $xpc;

}

1;

__END__;
